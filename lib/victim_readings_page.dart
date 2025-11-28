// lib/victim_readings_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    // Start with discovery mode
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
    // immediate UI feedback
    setState(() {
      _usingHosted = true;
      _error = null;
    });

    try {
      // switch ApiService to hosted (this returns an instance)
      final hosted = ApiService.forHosted();
      _apiService = hosted;

      // persist the choice so future launches use hosted
      // if ApiService.setCustomBase exists, this will persist; if not, see step 2.
      try {
        await ApiService.setCustomBase('https://web-production-87279.up.railway.app');
      } catch (e) {
        // not fatal — continue even if persistence helper is missing
        debugPrint('setCustomBase missing or failed: $e');
      }

      // reload data from hosted server and surface errors if any
      await _load();
    } catch (e, st) {
      debugPrint('useHosted error: $e\n$st');
      if (mounted) {
        setState(() {
          _error = 'Failed to switch to hosted backend: $e';
          _usingHosted = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final pdfUrl = await _apiService.pdfExportUrl();
      final uri = Uri.parse(pdfUrl);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("PDF error: $e")));
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
                        const SnackBar(content: Text("Cache cleared")));
                  }
                })
          ],
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
          // analytics cards
          Row(
            children: [
              _metricCard("Victims", "$total"),
              const SizedBox(width: 10),
              _metricCard("Avg Dist (cm)", avgDist.toStringAsFixed(1)),
              const SizedBox(width: 10),
              _metricCard("% with GPS", "$gpsPct%"),
            ],
          ),

          const SizedBox(height: 14),

          ...readings.map((r) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text("Victim: ${r.victimId}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      const SnackBar(content: Text("Copied victim ID")));
                },
              ),
            ),
          ))
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
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
              icon: const Icon(Icons.download),
              tooltip: "Download PDF",
              onPressed: _downloadPdf)
        ],
      ),
      body: _error != null
          ? _buildErrorCard()
          : FutureBuilder(
        future: _futureReadings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _error = snapshot.error.toString());
              }
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
                  ElevatedButton(
                      onPressed: _load, child: const Text("Reload"))
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