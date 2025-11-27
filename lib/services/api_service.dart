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
  // Port your Flask app uses on local/dev machines
  static const int _port = 5001;

  // Key for caching discovered base URL in shared prefs
  static const String _cacheKey = 'api_cached_base';

  // Timeouts
  static const Duration _probeTimeout = Duration(seconds: 3);
  static const Duration _requestTimeout = Duration(seconds: 8);

  // In-memory cache (fast)
  static String? _inMemoryBase;

  // Optional LAN hints (ip strings without port)
  final List<String> _lanHints;

  // Optional forced base (full URL, e.g. "https://web-production-...up.railway.app")
  final String? _forcedBase;

  // API key used for write operations (should match WRITE_API_KEY on server)
  final String writeApiKey;

  /// Constructor:
  /// - lanHints: list of IPs (without port) to probe first
  /// - forcedBase: if provided, used immediately (and persisted)
  /// - writeApiKey: header value to use for POSTs
  ApiService({List<String>? lanHints, String? forcedBase, this.writeApiKey = 'secret'})
      : _lanHints = lanHints ?? [],
        _forcedBase = forcedBase {
    if (_forcedBase != null) {
      _inMemoryBase = _forcedBase;
      // persist in background
      SharedPreferences.getInstance().then((prefs) => prefs.setString(_cacheKey, _forcedBase!));
    }
  }

  /// Helper factory to immediately use your Railway hosted backend
  factory ApiService.forHosted({String hostedUrl = 'https://web-production-87279.up.railway.app', String writeApiKey = 'secret'}) {
    return ApiService(forcedBase: hostedUrl, writeApiKey: writeApiKey);
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

  // Force probe (re-discovers)
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

  Future<VictimReading> fetchLatest(String victimId) async {
    final base = await _ensureBase();
    final url = '$base/api/v1/victims/$victimId/latest';
    final body = await _getWithFallback(url);
    final Map<String, dynamic> j = jsonDecode(body);
    return VictimReading.fromJson(j);
  }

  /// Returns the direct PDF export URL (so the UI can open it in browser)
  Future<String> pdfExportUrl() async {
    final base = await _ensureBase();
    return '$base/api/v1/readings/export/pdf';
  }

  /// Post a reading. Body must be a JSON-encodable map with keys:
  /// victim_id (optional), distance_cm (required), latitude, longitude
  Future<http.Response> postReading(Map<String, dynamic> body) async {
    final base = await _ensureBase();
    final uri = Uri.parse('$base/api/v1/readings');

    final resp = await http
        .post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': writeApiKey,
      },
      body: jsonEncode(body),
    )
        .timeout(_requestTimeout);

    return resp;
  }

  // ---------- Internal: ensure base exists ----------
  Future<String> _ensureBase() async {
    if (_inMemoryBase != null) return _inMemoryBase!;

    final prefs = await SharedPreferences.getInstance();

    // 1) persisted custom base
    final persisted = prefs.getString(_cacheKey);
    if (persisted != null) {
      if (await _probe(persisted)) {
        _inMemoryBase = persisted;
        return persisted;
      } else {
        await prefs.remove(_cacheKey);
      }
    }

    // 2) forcedBase provided in ctor (persist & return)
    if (_forcedBase != null) {
      _inMemoryBase = _forcedBase;
      await prefs.setString(_cacheKey, _forcedBase!);
      return _forcedBase!;
    }

    // 3) try localhost first on desktop (fast)
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      final local = 'http://127.0.0.1:$_port';
      if (await _probe(local)) {
        _inMemoryBase = local;
        await prefs.setString(_cacheKey, local);
        return local;
      }
    }

    // 4) try LAN hints (if provided)
    for (final ip in _lanHints) {
      final candidate = 'http://$ip:$_port';
      if (await _probe(candidate)) {
        _inMemoryBase = candidate;
        await prefs.setString(_cacheKey, candidate);
        return candidate;
      }
    }

    // 5) mDNS / zeroconf
    final mdnsBase = await _discoverViaMdns();
    if (mdnsBase != null) {
      _inMemoryBase = mdnsBase;
      await prefs.setString(_cacheKey, mdnsBase);
      return mdnsBase;
    }

    // 6) brute force a short list of likely addresses (fallback)
    final localProbeCandidates = [
      'http://192.168.0.100:$_port',
      'http://192.168.0.200:$_port',
      'http://10.0.2.2:$_port', // Android emulator host
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

      final ptrStream = client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer('_http._tcp.local'));

      await for (final PtrResourceRecord ptr in ptrStream.timeout(timeout)) {
        final srvStream = client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName));

        await for (final SrvResourceRecord srv in srvStream.timeout(timeout)) {
          final ipStream = client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target));

          await for (final IPAddressResourceRecord ipRec in ipStream.timeout(timeout)) {
            final ip = ipRec.address.address;
            final port = srv.port == 0 ? _port : srv.port;
            final base = 'http://$ip:$port';

            // FIXED
            try {
              client.stop();
            } catch (_) {}

            return base;
          }
        }
      }

      // FIXED
      try {
        client.stop();
      } catch (_) {}

    } catch (_) {
      // FIXED
      if (client != null) {
        try {
          client.stop();
        } catch (_) {}
      }
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

  // ---------- GET with fallback ----------
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