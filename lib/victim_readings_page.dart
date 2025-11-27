// lib/victim_readings_page.dart
import 'package:flutter/material.dart';
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
  String? _error; // discovery / network error message
  bool _usingHosted = false;

  @override
  void initState() {
    super.initState();
    // Start with "smart" discovery (no forced base).
    _apiService = ApiService(); // will try localhost, lanHints, mDNS...
    _load();
  }

  Future<void> _load({bool forceReload = false}) async {
    setState(() {
      _error = null;
      _futureReadings = _apiService.fetchAllReadings();
    });

    try {
      // await to surface any immediate errors so UI can show friendly message
      await _futureReadings;
      // success - nothing else needed
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _retryDiscovery() async {
    setState(() {
      _error = null;
    });
    try {
      // clear cached discovery and try again
      await ApiService.clearCache();
      _apiService = ApiService(); // fresh discovery
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _useHosted() async {
    // switch to hosted Railway server immediately
    final hosted = ApiService.forHosted();
    _apiService = hosted;
    _usingHosted = true;
    // persist choice inside ApiService.forHosted (it stores in prefs)
    await ApiService.setCustomBase('https://web-production-87279.up.railway.app');
    await _load();
  }

  Future<void> _downloadPdf() async {
    try {
      final pdfUrl = await _apiService.pdfExportUrl();
      final uri = Uri.parse(pdfUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open PDF download link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    }
  }

  Future<void> _refresh() async {
    try {
      // force fresh fetch
      final base = await _apiService.forceProbe();
      setState(() {
        _futureReadings = _apiService.fetchAllReadings();
        _error = null;
      });
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
              _error ?? 'Try retrying discovery or use the hosted backend.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Discovery'),
                  onPressed: _retryDiscovery,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud),
                  label: const Text('Use Hosted Backend'),
                  onPressed: _useHosted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              child: const Text('Advanced: Reset discovery cache'),
              onPressed: () async {
                await ApiService.clearCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discovery cache cleared')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<VictimReading> readings) {
    // analytics summary at top
    final total = readings.length;
    final avgDistance = (readings.isEmpty) ? 0 : (readings.map((r) => r.distanceCm).reduce((a, b) => a + b) / readings.length);
    final withGps = readings.where((r) => r.latitude != null && r.longitude != null).length;
    final gpsPct = total == 0 ? 0 : ((withGps / total) * 100).round();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // analytics cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Total victims detected', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Avg distance (cm)', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(avgDistance.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('% with GPS', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('$gpsPct%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // list of readings
          ...readings.map((r) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Victim: ${r.victimId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Distance: ${r.distanceCm} cm\nLat: ${r.latitude ?? 'N/A'} | Lon: ${r.longitude ?? 'N/A'}\nTime: ${r.timestamp}'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // copy victim id to clipboard
                    // no need for async state changes here
                    // use Flutter's Clipboard API if available
                    // import 'package:flutter/services.dart' at top if you want to enable
                  },
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _usingHosted ? 'Data Logging (Hosted)' : 'Data Logging';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: _downloadPdf,
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
          } else if (snapshot.hasError) {
            // surface the error and provide controls
            if (_error == null) {
              // capture it so we show the friendly card next build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _error = snapshot.error.toString());
              });
            }
            return _buildErrorCard();
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No readings found', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Reload')),
                ],
              ),
            );
          } else {
            final readings = snapshot.data!;
            return _buildList(readings);
          }
        },
      ),
    );
  }
}