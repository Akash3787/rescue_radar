// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/victim_reading.dart';

class ApiService {
  // TIMEOUTS
  static const Duration _requestTimeout = Duration(seconds: 8);

  // The base URL we will use (in-memory only)
  final String _base;

  ApiService._(this._base);

  /// Construct an ApiService that ALWAYS uses the hosted Railway backend.
  /// Replace the URL below if your hosted URL changes.
  factory ApiService.forHosted({
    String hostedUrl = 'https://web-production-87279.up.railway.app',
  }) {
    // remove trailing slash if present
    final b = hostedUrl.endsWith('/') ? hostedUrl.substring(0, hostedUrl.length - 1) : hostedUrl;
    return ApiService._(b);
  }

  // ---------- Public API ----------

  Future<List<VictimReading>> fetchAllReadings() async {
    final url = '$_base/api/v1/readings/all';
    final resp = await http.get(Uri.parse(url)).timeout(_requestTimeout);
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch readings (${resp.statusCode}): ${resp.body}');
    }
    final List<dynamic> j = jsonDecode(resp.body);
    return j.map((e) => VictimReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> pdfExportUrl() async {
    return '$_base/api/v1/readings/export/pdf';
  }

  /// Post a reading to the hosted backend.
  /// `writeApiKey` defaults to 'secret' to match your backend; change if needed.
  Future<http.Response> postReading(Map<String, dynamic> body, {String writeApiKey = 'secret'}) async {
    final uri = Uri.parse('$_base/api/v1/readings');
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

  /// Force-probe placeholder — for compatibility with UI code
  Future<String> forceProbe() async {
    // On hosted-only mode, base is known already.
    return _base;
  }

  String get baseUrl => _base;
}