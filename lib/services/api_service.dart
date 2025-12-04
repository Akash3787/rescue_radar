import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/victim_reading.dart';

class ApiService {
  static const String _cacheKey = 'api_cached_base';
  static const String _hostedBase = 'https://web-production-87279.up.railway.app';
  static const Duration _requestTimeout = Duration(seconds: 8);
  static String? _inMemoryBase;
  final String writeApiKey;

  ApiService({this.writeApiKey = 'secret'}) {
    _inMemoryBase = _hostedBase;
  }

  factory ApiService.forHosted({String writeApiKey = 'secret'}) {
    return ApiService(writeApiKey: writeApiKey);
  }

  static Future<void> clearCache() async {
    _inMemoryBase = null;
    if (kIsWeb) return; // skip for web
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  static Future<void> setCustomBase(String base) async {
    _inMemoryBase = base;
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, base);
  }

  Future<List<VictimReading>> fetchAllReadings() async {
    final url = '$_hostedBase/api/v1/readings/all';
    final body = await _getWithFallback(url);
    final Map<String, dynamic> jsonMap = jsonDecode(body);

    final List<dynamic> readingsJson = jsonMap['readings'];
    return readingsJson.map((e) => VictimReading.fromJson(e)).toList();
  }

  Future<List<VictimReading>> fetchReadingsForVictim(String victimId) async {
    // Fetch all readings and filter by victim ID
    final allReadings = await fetchAllReadings();
    return allReadings.where((r) => r.victimId == victimId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Sort by timestamp
  }

  Future<VictimReading> fetchLatest(String victimId) async {
    final url = '$_hostedBase/api/v1/victims/$victimId/latest';
    final body = await _getWithFallback(url);
    final Map<String, dynamic> j = jsonDecode(body);
    return VictimReading.fromJson(j);
  }

  Future<String> pdfExportUrl() async {
    return '$_hostedBase/api/v1/readings/export/pdf';
  }

  Future<http.Response> postReading(Map<String, dynamic> body) async {
    final uri = Uri.parse('$_hostedBase/api/v1/readings');

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': writeApiKey,
      },
      body: jsonEncode(body),
    ).timeout(_requestTimeout);

    return resp;
  }

  Future<String> _getWithFallback(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (resp.statusCode == 200) return resp.body;
      throw Exception('Server returned ${resp.statusCode}');
    } catch (_) {
      await clearCache();
      final retryResp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
      if (retryResp.statusCode == 200) return retryResp.body;
      throw Exception('Request failed after fallback: ${retryResp.statusCode}');
    }
  }
}
