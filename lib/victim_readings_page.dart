import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _usingHosted = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _futureReadings = _apiService.fetchAllReadings();
    });
    try {
      await _futureReadings;
      if (mounted) setState(() {});
    } catch (e) {
      developer.log('Load error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _retryDiscovery() async {
    setState(() => _error = null);
    try {
      await ApiService.clearCache();
      _apiService = ApiService();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _useHosted() async {
    developer.log('🔄 Switching to hosted backend...');
    setState(() {
      _usingHosted = true;
      _error = null;
    });

    try {
      final hosted = ApiService.forHosted();
      _apiService = hosted;
      developer.log('✅ ApiService switched to hosted');

      try {
        final hosted = await Future<ApiService>.sync(() {
          return ApiService.forHosted();
        });
        _apiService = hosted;
        developer.log('✅ ApiService switched to hosted');
      } catch (e, st) {
        developer.log('❌ ApiService.forHosted() threw: $e\n$st');
        if (mounted) {
          setState(() {
            _error = 'Error creating hosted ApiService: $e';
            _usingHosted = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Hosted init failed: $e")),
          );
        }
        return;
      }

      try {
        await ApiService.setCustomBase('https://web-production-87279.up.railway.app');
        developer.log('✅ Custom base URL set');
      } catch (e, st) {
        developer.log('⚠️ setCustomBase failed (OK if method missing): $e\n$st');
      }

      await _load();
      developer.log('🔥 Hosted loaded OK!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Switched to hosted backend!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      developer.log('❌ useHosted ERROR: $e\n$st');
      if (mounted) {
        setState(() {
          _error = 'Hosted backend failed: $e';
          _usingHosted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Hosted failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ CORRECTED: Browser-based PDF download (exactly like Chrome copy-paste)
  Future<void> _downloadPdf() async {
    const pdfUrl = "https://web-production-87279.up.railway.app/api/v1/readings/export/pdf";

    try {
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,  // Opens in external browser (Chrome/Safari)
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("📥 Opening in browser to download PDF..."),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not launch $pdfUrl');
      }
    } catch (e) {
      developer.log('❌ Browser launch ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to open browser: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    try {
      await _apiService.forceProbe();
      if (mounted) {
        setState(() {
          _futureReadings = _apiService.fetchAllReadings();
          _error = null;
        });
      }
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
              'Could not discover backend on local network',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Try retrying or switch to hosted backend.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Discovery'),
                  onPressed: _retryDiscovery,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud),
                  label: const Text('Use Hosted'),
                  onPressed: _useHosted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              child: const Text("Clear discovery cache"),
              onPressed: () async {
                await ApiService.clearCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cache cleared")),
                  );
                }
              },
            )
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
    final title = _usingHosted ? "Data Logging (Hosted)" : "Data Logging";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
