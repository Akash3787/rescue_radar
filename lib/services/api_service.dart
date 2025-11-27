// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/victim_reading.dart';

class ApiService {
  // CONFIG - update lanIp when your host changes networks
  static const int _port = 5001;

  // Put your usual LAN IP here as a hint (can be empty string if you prefer)
  // e.g. '172.20.45.32'
  static const String lanIpHint = '172.20.45.32';

  // Optional public endpoints (ngrok or other)
  static const List<String> publicUrls = [
    // 'https://abcd1234.ngrok-free.app',
  ];

  // SharedPreferences key
  static const String _kCachedBaseKey = 'api_cached_base';

  // probe/persistence params
  static const Duration _probeTimeout = Duration(seconds: 3);
  static const int _probeRetries = 2;
  static const Duration _requestTimeout = Duration(seconds: 8);

  // in-memory cached base
  static String? _inMemoryCachedBase;

  // candidates built at runtime
  late final List<String> _candidates;

  ApiService() {
    _candidates = _buildCandidates();
  }

  // Build candidate list in the preferred order
  List<String> _buildCandidates() {
    final List<String> c = [];

    // 1) If desktop, prefer localhost first (most dev flows)
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      c.add('http://127.0.0.1:$_port');
    }

    // 2) LAN hint
    if (lanIpHint.isNotEmpty) {
      c.add('http://$lanIpHint:$_port');
    }

    // 3) any public urls
    for (final u in publicUrls) {
      final normalized = u.endsWith('/') ? u.substring(0, u.length - 1) : u;
      c.add(normalized);
    }

    // 4) final fallback: localhost (ensure it's present)
    final localhost = 'http://127.0.0.1:$_port';
    if (!c.contains(localhost)) c.add(localhost);

    return c;
  }

  // Clear both memory and persisted cache
  static Future<void> clearCache() async {
    _inMemoryCachedBase = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedBaseKey);
  }

  // Allow developer override
  static Future<void> setCustomBase(String base) async {
    _inMemoryCachedBase = base;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedBaseKey, base);
  }

  // Force a reprobe and return chosen base
  Future<String> forceProbe() async {
    _inMemoryCachedBase = null;
    return await _ensureBaseUrl();
  }

  // Public: fetch all readings (list)
  Future<List<VictimReading>> fetchAllReadings() async {
    final base = await _ensureBaseUrl();
    final url = '$base/api/v1/readings/all';
    final body = await _getWithFallback(url);
    final List<dynamic> j = jsonDecode(body);
    return j.map((e) => VictimReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ==== internal: ensure we have a cached/persisted base ====
  Future<String> _ensureBaseUrl() async {
    // in-memory first
    if (_inMemoryCachedBase != null) return _inMemoryCachedBase!;

    // persisted cache
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_kCachedBaseKey);
    if (persisted != null && persisted.isNotEmpty) {
      _inMemoryCachedBase = persisted;
      // quick validation: probe it once quickly
      final ok = await _probe(persisted);
      if (ok) return _inMemoryCachedBase!;
      // if not ok, clear and continue probing
      _inMemoryCachedBase = null;
      await prefs.remove(_kCachedBaseKey);
    }

    // probe candidates sequentially
    for (final c in _candidates) {
      final ok = await _probe(c);
      if (ok) {
        _inMemoryCachedBase = c;
        await prefs.setString(_kCachedBaseKey, c);
        return c;
      }
    }

    throw Exception('Could not reach any backend candidates: ${_candidates.join(', ')}');
  }

  // probe a single base by requesting /api/v1/readings/all
  Future<bool> _probe(String candidate) async {
    int attempt = 0;
    while (attempt < _probeRetries) {
      try {
        final uri = Uri.parse(candidate + '/api/v1/readings/all');
        final resp = await http.get(uri).timeout(_probeTimeout);
        if (resp.statusCode == 200) return true;
      } on TimeoutException {
        // retry
      } on SocketException {
        // retry
      } catch (_) {
        // treat as failure
      }
      attempt++;
      await Future.delayed(Duration(milliseconds: 150 * (1 << attempt)));
    }
    return false;
  }

  // perform GET; on failure force reprobe once and retry
  Future<String> _getWithFallback(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (resp.statusCode == 200) return resp.body;
      throw HttpException('Server responded ${resp.statusCode}');
    } on Exception catch (_) {
      // clear cached base and try reprobe (once)
      await clearCache();
      final base = await _ensureBaseUrl();
      final retryUrl = _replaceBase(url, base);
      final retryResp = await http.get(Uri.parse(retryUrl)).timeout(_requestTimeout);
      if (retryResp.statusCode == 200) return retryResp.body;
      throw Exception('Request failed after fallback: ${retryResp.statusCode}');
    }
  }

  String _replaceBase(String url, String newBase) {
    final uri = Uri.parse(url);
    final path = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final nb = newBase.endsWith('/') ? newBase.substring(0, newBase.length - 1) : newBase;
    return '$nb$path';
  }
}