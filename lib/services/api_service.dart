// lib/services/api_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/victim_reading.dart';

class ApiService {
  // CHANGE THIS to the correct host if needed.
  // Use HTTPS for production; if testing locally on macOS use http://127.0.0.1:5001
  // For Railway, use the full https://<your-railway-host>
  static const String defaultBaseUrl = "https://web-production-87279.up.railway.app";
  // fallback to http if https times out or fails (auto-try)
  final String baseUrl;
  final String writeApiKey;

  late final Dio dio;

  ApiService({String? baseUrlOverride, String? writeKey})
      : baseUrl = baseUrlOverride ?? defaultBaseUrl,
        writeApiKey = writeKey ?? "rescue-radar-dev" {
    dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        "Content-Type": "application/json",
        "x-api-key": this.writeApiKey,
      },
    ));

    // Verbose logging interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        developer.log("DIO → REQUEST: ${options.method} ${options.uri}", name: "ApiService");
        developer.log("DIO → Headers: ${options.headers}", name: "ApiService");
        if (options.data != null) developer.log("DIO → Body: ${options.data}", name: "ApiService");
        handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log("DIO ← RESPONSE: ${response.statusCode} ${response.requestOptions.uri}", name: "ApiService");
        developer.log("DIO ← Body: ${response.data}", name: "ApiService");
        handler.next(response);
      },
      onError: (DioError e, handler) async {
        developer.log("DIO !! ERROR: type=${e.type} message=${e.message}", name: "ApiService");
        if (e.response != null) {
          developer.log("DIO !! ERROR RESPONSE: status=${e.response?.statusCode} body=${e.response?.data}", name: "ApiService");
        } else {
          developer.log("DIO !! NO RESPONSE — possible network/SSL issue", name: "ApiService");
        }

        // Fallback: if HTTPS failed due to TLS or connection, retry with HTTP (only once)
        final uri = e.requestOptions.uri;
        if (uri.scheme == 'https') {
          try {
            final httpUrl = uri.replace(scheme: 'http').toString();
            developer.log("DIO !! Retrying over HTTP: $httpUrl", name: "ApiService");
            final opts = Options(
              method: e.requestOptions.method,
              headers: e.requestOptions.headers,
              responseType: e.requestOptions.responseType,
            );
            final response = await Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
            )).request(
              httpUrl,
              data: e.requestOptions.data,
              options: opts,
              queryParameters: e.requestOptions.queryParameters,
            );
            handler.resolve(response);
            return;
          } catch (retryError) {
            developer.log("DIO !! HTTP retry failed: $retryError", name: "ApiService");
            // fall through to error handler
          }
        }

        handler.next(e);
      },
    ));
  }

  // Factory for hosted default
  factory ApiService.forHosted({String? baseUrlOverride, String? writeKey}) =>
      ApiService(baseUrlOverride: baseUrlOverride, writeKey: writeKey);

  // Fetch all readings
  Future<List<VictimReading>> fetchAllReadings({int page = 1, int perPage = 50}) async {
    final endpoint = "/api/v1/readings/all";
    try {
      final resp = await dio.get(endpoint, queryParameters: {"page": page, "per_page": perPage});
      if (resp.statusCode == 200) {
        final data = resp.data;
        final list = <VictimReading>[];
        if (data is Map && data['readings'] is List) {
          for (final item in data['readings']) {
            try {
              list.add(VictimReading.fromJson(Map<String, dynamic>.from(item)));
            } catch (e, st) {
              developer.log("Parsing reading failed: $e\n$st", name: "ApiService");
            }
          }
        }
        return list;
      } else {
        throw Exception('Server returned ${resp.statusCode}');
      }
    } catch (e, st) {
      developer.log("fetchAllReadings ERROR: $e\n$st", name: "ApiService");
      rethrow;
    }
  }

  // Fetch latest reading
  Future<VictimReading?> fetchLatest() async {
    final endpoint = "/api/v1/readings/latest";
    try {
      final resp = await dio.get(endpoint);
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map && data['reading'] != null) {
          return VictimReading.fromJson(Map<String, dynamic>.from(data['reading']));
        }
        return null;
      } else {
        throw Exception('Server returned ${resp.statusCode}');
      }
    } catch (e, st) {
      developer.log("fetchLatest ERROR: $e\n$st", name: "ApiService");
      rethrow;
    }
  }

  // Post a reading (create/update)
  Future<VictimReading> postReading(Map<String, dynamic> payload) async {
    final endpoint = "/api/v1/readings";
    try {
      final resp = await dio.post(endpoint, data: payload);
      if (resp.statusCode == 200 && resp.data is Map && resp.data['reading'] != null) {
        return VictimReading.fromJson(Map<String, dynamic>.from(resp.data['reading']));
      } else {
        throw Exception('Unexpected response: ${resp.statusCode} ${resp.data}');
      }
    } catch (e, st) {
      developer.log("postReading ERROR: $e\n$st", name: "ApiService");
      rethrow;
    }
  }

  // Fetch readings for a specific victim (helper method)
  Future<List<VictimReading>> fetchReadingsForVictim(String victimId) async {
    final allReadings = await fetchAllReadings(page: 1, perPage: 500);
    return allReadings
        .where((r) => r.victimId == victimId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}