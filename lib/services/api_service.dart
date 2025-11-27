// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
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
  final String? _forcedBase; // if provided, use this immediately

  /// Constructor:
  /// - forcedBase: full base URL like "http://172.20.45.32:5001" (will be used and persisted)
  /// - lanHints: list of IPs (without port) to probe first, e.g. ['172.20.45.32']
  ApiService({List<String>? lanHints, String? forcedBase})
      : _lanHints = lanHints ?? [],
        _forcedBase = forcedBase {
    if (_forcedBase != null) {
      // set immediately in memory and persist (fire-and-forget)
      _inMemoryBase = _forcedBase;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_cacheKey, _forcedBase!);
      });
    }
  }

  // Public: clear persisted/in-memory cache
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

  // Force probe
  Future<String> forceProbe() async {
    _inMemoryBase = null;
    return await _ensureBase();
  }

  // ---------- Public API ----------
  Future<List<VictimReading>> fetchAllReadings() async {
    final base = await _ensureBase();
    final url = '$base/api/v1/readings/all';
    final body = await _getWithFallback(url);
    final List<dynamic> j = jsonDecode(body);
    return j.map((e) => VictimReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------- Internal: ensure base exists ----------
  Future<String> _ensureBase() async {
    if (_inMemoryBase != null) return _inMemoryBase!;

    final prefs = await SharedPreferences.getInstance();

    // If a persisted custom base exists, validate it
    final persisted = prefs.getString(_cacheKey);
    if (persisted != null) {
      final ok = await _probe(persisted);
      if (ok) {
        _inMemoryBase = persisted;
        return persisted;
      } else {
        await prefs.remove(_cacheKey);
      }
    }

    // If constructor forced a base (persisted already), return it
    if (_forcedBase != null) {
      _inMemoryBase = _forcedBase;
      await prefs.setString(_cacheKey, _forcedBase!);
      return _forcedBase!;
    }

    // 1) Try localhost first on desktop
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final local = 'http://127.0.0.1:$_port';
      if (await _probe(local)) {
        _inMemoryBase = local;
        await prefs.setString(_cacheKey, local);
        return local;
      }
    }

    // 2) Try LAN hints provided by user (fast & reliable)
    for (final ip in _lanHints) {
      final candidate = 'http://$ip:$_port';
      if (await _probe(candidate)) {
        _inMemoryBase = candidate;
        await prefs.setString(_cacheKey, candidate);
        return candidate;
      }
    }

    // 3) Try mDNS / zeroconf
    final mdnsBase = await _discoverViaMdns();
    if (mdnsBase != null) {
      _inMemoryBase = mdnsBase;
      await prefs.setString(_cacheKey, mdnsBase);
      return mdnsBase;
    }

    // 4) Brute-force local known candidates (fallback)
    final localProbeCandidates = [
      'http://192.168.0.100:$_port',
      'http://192.168.0.200:$_port',
      'http://10.0.2.2:$_port',
    ];
    for (final c in localProbeCandidates) {
      if (await _probe(c)) {
        _inMemoryBase = c;
        await prefs.setString(_cacheKey, c);
        return c;
      }
    }

    throw Exception('Could not discover backend on local network.');
  }

  // ---------- mDNS discovery ----------
  Future<String?> _discoverViaMdns({Duration timeout = const Duration(seconds: 3)}) async {
    MDnsClient? client;
    try {
      client = MDnsClient();
      await client.start();
      final ptrStream = client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_http._tcp.local'));
      await for (final PtrResourceRecord ptr in ptrStream.timeout(timeout)) {
        final srvStream = client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName));
        await for (final SrvResourceRecord srv in srvStream.timeout(timeout)) {
          final ipStream = client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target));
          await for (final IPAddressResourceRecord ipRec in ipStream.timeout(timeout)) {
            final ip = ipRec.address.address;
            final port = srv.port == 0 ? _port : srv.port;
            final base = 'http://$ip:$port';
            // stop the client (client.stop() returns void in this mdns package)
            try {
              client.stop();
            } catch (_) {}
            return base;
          }
        }
      }
      // stop if nothing found
      try {
        client.stop();
      } catch (_) {}
    } catch (_) {
      // ensure client is stopped on error
      try {
        if (client != null) client.stop();
      } catch (_) {}
    }
    return null;
  }

  // ---------- Probe helper ----------
  Future<bool> _probe(String base) async {
    try {
      final uri = Uri.parse(base + '/api/v1/readings/all');
      final resp = await http.get(uri).timeout(_probeTimeout);
      return resp.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  // ---------- GET w/ fallback (reprobe once if cached base fails) ----------
  Future<String> _getWithFallback(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (resp.statusCode == 200) return resp.body;
      throw HttpException('Server returned ${resp.statusCode}');
    } on Exception {
      // clear cached base and reprobe once
      await clearCache();
      final base = await _ensureBase();
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