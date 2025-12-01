import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'models/victim_reading.dart';
import 'services/api_service.dart';

class VictimReadingsPage extends StatefulWidget {
  const VictimReadingsPage({super.key});

  @override
  State<VictimReadingsPage> createState() => _VictimReadingsPageState();
}

class _VictimReadingsPageState extends State<VictimReadingsPage> {
  late ApiService _apiService;
  late Future<List<VictimReading>> _futureReadings;
  String? _error;
  bool _usingHosted = true; // always hosted now
  bool _isDownloading = false;

  bool get _supportsPathProvider => !(kIsWeb || (Platform.isMacOS));

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

  Future<void> _useHosted() async {
    // No switching needed, already hosted
    // But method kept for compatibility if logic changes
    developer.log('🔄 Using hosted backend (default)');
    setState(() {
      _usingHosted = true;
      _error = null;
      _futureReadings = _apiService.fetchAllReadings();
    });
  }

  Future<void> _downloadPdf() async {
    const pdfUrl = "https://web-production-87279.up.railway.app/api/v1/readings/export/pdf";
    const apiKey = "secret"; // ideally get from config or secure storage

    if (!_supportsPathProvider) {
      // Fallback for Web/macOS: open PDF URL in browser (no headers, so public access only)
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("📥 Opening PDF in browser..."), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Could not launch browser"), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception("Storage permission denied");
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          "${dir.path}/victim_readings_${DateTime.now().millisecondsSinceEpoch}.pdf";

      final dio = Dio();
      final resp = await dio.get<List<int>>(
        pdfUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            "x-api-key": apiKey,
          },
        ),
      );

      final file = File(filePath);
      await file.writeAsBytes(resp.data!, flush: true);

      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ PDF downloaded and opened"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('❌ PDF download ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ PDF failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      setState(() {
        _futureReadings = _apiService.fetchAllReadings();
        _error = null;
      });
      await _futureReadings;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _buildErrorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'Could not load data from backend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Try reloading the page.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: color.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 14, color: color)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<VictimReading> readings) {
    final total = readings.length;
    final avgDist = total == 0
        ? 0
        : (readings.map((e) => e.distanceCm).reduce((a, b) => a + b) / total);
    final gpsCount = readings.where((r) => r.latitude != null).length;
    final gpsPct = total == 0 ? 0 : ((gpsCount / total) * 100).round();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _metricCard("Victims", "$total", Icons.person, Colors.blue),
              const SizedBox(width: 10),
              _metricCard("Avg Dist (cm)", avgDist.toStringAsFixed(1), Icons.straighten, Colors.green),
              const SizedBox(width: 10),
              _metricCard("% with GPS", "$gpsPct%", Icons.location_on, Colors.orange),
            ],
          ),
          const SizedBox(height: 14),
          ...readings.map((r) => Card(
            elevation: 3,
            shadowColor: Colors.grey[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              title: Text("Victim: ${r.victimId}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                "Distance: ${r.distanceCm} cm\n"
                    "Lat: ${r.latitude ?? "N/A"} | Lon: ${r.longitude ?? "N/A"}\n"
                    "Time: ${r.timestamp}",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: r.victimId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied victim ID")),
                  );
                },
              ),
            ),
          ))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const title = "Data Logging (Hosted)";

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          IconButton(
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
            tooltip: "Download PDF",
            onPressed: _isDownloading ? null : _downloadPdf,
          )
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
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _error = snapshot.error.toString());
            });
            return _buildErrorCard();
          }
          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("No readings found"),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _load, child: const Text("Reload"))
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
