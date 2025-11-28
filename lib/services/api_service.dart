// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/victim_reading.dart';

class ApiService {
  static const int _port = 5001;
  static const String _cacheKey = 'api_cached_base';

  static const Duration _probeTimeout = Duration(seconds: 3);
  static const Duration _requestTimeout = Duration(seconds: 8);

  static String? _inMemoryBase;

  final List<String> _lanHints;
  final String? _forcedBase;
  final String writeApiKey;

  ApiService({List<String>? lanHints, String? forcedBase, this.writeApiKey = 'secret'})
      : _lanHints = lanHints ?? [],
        _forcedBase = forcedBase {
    if (_forcedBase != null) {
      _inMemoryBase = _forcedBase;
      SharedPreferences.getInstance().then(
            (prefs) => prefs.setString(_cacheKey, _forcedBase!),
      );
    }
  }

  /// Factory shortcut for your Railway backend
  factory ApiService.forHosted({
    String hostedUrl = 'https://web-production-87279.up.railway.app',
    String writeApiKey = 'secret',
  }) {
    return ApiService(forcedBase: hostedUrl, writeApiKey: writeApiKey);
  }

  // ----------------------------------------------------
  // PUBLIC API
  // ----------------------------------------------------

  static Future<void> clearCache() async {
    _inMemoryBase = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // Public: set custom base (persist)
  static Future<void> setCustomBase(String base) async {
    _inMemoryBase = base;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, base);
  }

  Future<String> forceProbe() async {
    _inMemoryBase = null;
    return await _ensureBase();
  }

  Future<List<VictimReading>> fetchAllReadings() async {
    final base = await _ensureBase();
    final url = '$base/api/v1/readings/all';
    final body = await _getWithFallback(url);

    final List<dynamic> j = jsonDecode(body);
    return j.map((e) => VictimReading.fromJson(e)).toList();
  }

  Future<VictimReading> fetchLatest(String victimId) async {
    final base = await _ensureBase();
    final url = '$base/api/v1/victims/$victimId/latest';
    final body = await _getWithFallback(url);
    return VictimReading.fromJson(jsonDecode(body));
  }

  Future<String> pdfExportUrl() async {
    final base = await _ensureBase();
    return '$base/api/v1/readings/export/pdf';
  }

  Future<http.Response> postReading(Map<String, dynamic> body) async {
    final base = await _ensureBase();
    final uri = Uri.parse('$base/api/v1/readings');

    return await http
        .post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': writeApiKey,
      },
      body: jsonEncode(body),
    )
        .timeout(_requestTimeout);
  }

  // ----------------------------------------------------
  // BASE DISCOVERY (NO MDNS)
  // ----------------------------------------------------
  Future<String> _ensureBase() async {
    if (_inMemoryBase != null) return _inMemoryBase!;

    final prefs = await SharedPreferences.getInstance();

    // 1 — persisted base
    final persisted = prefs.getString(_cacheKey);
    if (persisted != null && await _probe(persisted)) {
      _inMemoryBase = persisted;
      return persisted;
    }

    // 2 — forced base
    if (_forcedBase != null) {
      _inMemoryBase = _forcedBase;
      await prefs.setString(_cacheKey, _forcedBase!);
      return _forcedBase!;
    }

    // 3 — localhost on desktop
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final local = 'http://127.0.0.1:$_port';
      if (await _probe(local)) {
        _inMemoryBase = local;
        await prefs.setString(_cacheKey, local);
        return local;
      }
    }

    // 4 — LAN hints (rarely used)
    for (final ip in _lanHints) {
      final candidate = 'http://$ip:$_port';
      if (await _probe(candidate)) {
        _inMemoryBase = candidate;
        await prefs.setString(_cacheKey, candidate);
        return candidate;
      }
    }

    // 5 — fallback brute-force (optional)
    final candidates = [
      'http://192.168.0.100:$_port',
      'http://192.168.0.200:$_port',
      'http://10.0.2.2:$_port',
    ];
    for (final c in candidates) {
      if (await _probe(c)) {
        _inMemoryBase = c;
        await prefs.setString(_cacheKey, c);
        return c;
      }
    }

    throw Exception('Could not discover backend.');
  }

  // ----------------------------------------------------
  // Probe
  // ----------------------------------------------------
  Future<bool> _probe(String base) async {
    try {
      final uri = Uri.parse('$base/api/v1/readings/all');
      final resp = await http.get(uri).timeout(_probeTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------
  // GET fallback
  // ----------------------------------------------------
  Future<String> _getWithFallback(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (resp.statusCode == 200) return resp.body;

      throw Exception("Server returned ${resp.statusCode}");
    } catch (_) {
      await clearCache();
      final base = await _ensureBase();
      final fixed = _replaceBase(url, base);

      final retry = await http.get(Uri.parse(fixed)).timeout(_requestTimeout);
      if (retry.statusCode == 200) return retry.body;

      throw Exception("Failed after fallback (${retry.statusCode})");
    }
  }

  String _replaceBase(String url, String newBase) {
    final uri = Uri.parse(url);
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

    final clean = newBase.endsWith('/') ? newBase.substring(0, newBase.length - 1) : newBase;

    return '$clean$path';
  }
}