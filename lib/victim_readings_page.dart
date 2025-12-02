import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'models/victim_reading.dart';
import 'services/api_service.dart';
import 'package:geolocator/geolocator.dart';

class VictimReadingsPage extends StatefulWidget {
  const VictimReadingsPage({super.key});

  @override
  State<VictimReadingsPage> createState() => _VictimReadingsPageState();
}

class _VictimReadingsPageState extends State<VictimReadingsPage> {
  late ApiService _apiService;
  late Future<List<VictimReading>> _futureReadings;
  String? _error;
  bool _usingHosted = true;
  bool _isDownloading = false;

  bool get _supportsPathProvider => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _futureReadings = _apiService.fetchAllReadings();
    });
    try {
      await _futureReadings;
    } catch (e) {
      developer.log('Load error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openMap(double lat, double lon) async {
    developer.log('🗺️ FORCE OPENING map: $lat, $lon');

    // The ONE URL that works everywhere - Google Maps web
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');

    try {
      // FORCE launch - no checks, no canLaunchUrl
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      developer.log('✅ Google Maps FORCE opened');
    } catch (e) {
      developer.log('❌ Primary launch failed: $e');

      // IMMEDIATE fallback - try platform browser
      try {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );
        developer.log('✅ Platform browser opened');
      } catch (e2) {
        developer.log('❌ Platform fallback failed: $e2');

        // FINAL FORCE - system default browser
        try {
          await launchUrl(googleMapsUrl);
          developer.log('✅ System browser FORCE opened');
        } catch (e3) {
          developer.log('❌ ALL launches failed: $e3');
          // Silent fail - no user notification
        }
      }
    }
  }





  Future<void> _downloadPdf() async {
    developer.log('📥 Download started');
    const pdfUrl = "https://web-production-87279.up.railway.app/api/v1/readings/export/pdf";

    if (kIsWeb) {
      // Web: direct browser download
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("📥 Opening PDF in browser"), backgroundColor: Colors.green),
          );
        }
      }
      return;
    }

    if (!mounted) return;

    setState(() => _isDownloading = true);

    try {
      // Android permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          throw Exception("Storage permission required");
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = "victim_readings_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final filePath = "${dir.path}/$fileName";

      developer.log('📁 Saving to: $filePath');

      final dio = Dio();
      final response = await dio.download(
        pdfUrl,
        filePath,
        options: Options(
          headers: {"x-api-key": "secret"}, // Replace with your actual key
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final result = await OpenFile.open(filePath);
        developer.log('✅ PDF opened: ${result.message}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ PDF saved & opened: ${result.message}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Download error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _refresh() async {
    developer.log('🔄 Refreshing...');
    try {
      if (mounted) {
        setState(() {
          _futureReadings = _apiService.fetchAllReadings();
          _error = null;
        });
      }
      await _futureReadings;
    } catch (e) {
      developer.log('Refresh error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _buildErrorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            const Text(
              'Connection Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<VictimReading> readings) {
    final total = readings.length;
    final avgDist = total == 0
        ? 0.0
        : readings.map((e) => e.distanceCm).reduce((a, b) => a + b) / total;
    final gpsCount = readings.where((r) => r.latitude != null && r.longitude != null).length;
    final gpsPct = total == 0 ? 0 : ((gpsCount / total) * 100).round();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: readings.length + 1, // +1 for metrics row
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _metricCard("Victims", "$total", Icons.people, Colors.blue),
                    const SizedBox(width: 12),
                    _metricCard("Avg Dist", "${avgDist.toStringAsFixed(1)}cm", Icons.straighten, Colors.green),
                    const SizedBox(width: 12),
                    _metricCard("GPS", "$gpsPct%", Icons.location_on, Colors.orange),
                  ],
                ),
              ),
            );
          }

          final reading = readings[index - 1];
          return Card(
            margin: const EdgeInsets.only(top: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  reading.victimId.substring(reading.victimId.length - 2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text("Victim ${reading.victimId}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Distance: ${reading.distanceCm.toStringAsFixed(1)} cm"),
                  Text("Lat: ${reading.latitude ?? 'N/A'}, Lon: ${reading.longitude ?? 'N/A'}"),
                  Text("Time: ${reading.timestamp}"),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map button with proper padding
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: Icon(Icons.map, size: 20),
                      tooltip: "Open Maps",
                      onPressed: reading.latitude != null && reading.longitude != null
                          ? () => _openMap(reading.latitude!, reading.longitude!)
                          : null,
                    ),
                  ),
                  // Copy button
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: "Copy ID",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reading.victimId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Copied victim ID")),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Logging"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Download button - FIXED with padding and constraints
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: _isDownloading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.download),
              tooltip: "Download PDF Report",
              onPressed: _isDownloading ? null : _downloadPdf,
            ),
          ),
          // Refresh button
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _refresh,
          ),
        ],
      ),
      body: _error != null
          ? _buildErrorCard()
          : FutureBuilder<List<VictimReading>>(
        future: _futureReadings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _buildErrorCard();
          }
          final data = snapshot.data!;
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("No readings found", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reload"),
                  ),
                ],
              ),
            );
          }
          return _buildList(data);
        },
      ),
    );
  }
}
