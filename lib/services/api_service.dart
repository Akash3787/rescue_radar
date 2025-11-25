// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/victim_reading.dart';

class ApiService {
  // Desktop (macOS app + Flask running on same machine)
  final String baseUrl = 'http://127.0.0.1:5001';

  Future<List<VictimReading>> fetchAllReadings() async {
    final url = Uri.parse('$baseUrl/api/v1/readings/all');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((e) => VictimReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load readings: ${response.body}');
    }
  }
}