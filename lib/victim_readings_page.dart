// lib/victim_readings_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // for Clipboard

import 'models/victim_reading.dart';
import 'services/api_service.dart';

class VictimReadingsPage extends StatefulWidget {
  const VictimReadingsPage({super.key});

  @override
  State<VictimReadingsPage> createState() => _VictimReadingsPageState();
}

class _VictimReadingsPageState extends State<VictimReadingsPage> {
  late final ApiService _apiService;
  late Future<List<VictimReading>> _futureReadings;
  String? _error;
  bool _usingHosted = true; // UI shows hosted by default with this fallback

  @override
  void initState() {
    super.initState();
    // FORCE hosted backend to avoid platform plugin issues:
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
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final pdfUrl = await _apiService.pdfExportUrl();
      final uri = Uri.parse(pdfUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open PDF link')));
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
      await _apiService.forceProbe();
      setState(() {
        _futureReadings = _apiService.fetchAllReadings();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _readingToJsonString(VictimReading r) {
    // Minimal JSON string without depending on any model helper
    final m = {
      'id': r.id,
      'victim_id': r.victimId,
      'distance_cm': r.distanceCm,
      'latitude': r.latitude,
      'longitude': r.longitude,
      'timestamp': r.timestamp,
    };
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  Widget _buildList(List<VictimReading> readings) {
    final total = readings.length;
    final avgDistance = (readings.isEmpty)
        ? 0
        : (readings.map((r) => r.distanceCm).reduce((a, b) => a + b) / readings.length);
    final withGps = readings.where((r) => r.latitude != null && r.longitude != null).length;
    final gpsPct = total == 0 ? 0 : ((withGps / total) * 100).round();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          ...readings.map((r) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Victim: ${r.victimId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Distance: ${r.distanceCm} cm\nLat: ${r.latitude ?? 'N/A'} | Lon: ${r.longitude ?? 'N/A'}\nTime: ${r.timestamp}'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    final json = _readingToJsonString(r);
                    Clipboard.setData(ClipboardData(text: json));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading copied to clipboard')));
                    }
                  },
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
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
              'Backend error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _load,
            ),
          ],
        ),
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
          IconButton(icon: const Icon(Icons.download), tooltip: 'Download PDF', onPressed: _downloadPdf),
        ],
      ),
      body: FutureBuilder<List<VictimReading>>(
        future: _futureReadings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || _error != null) {
            if (_error == null) {
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
            return _buildList(snapshot.data!);
          }
        },
      ),
    );
  }
}