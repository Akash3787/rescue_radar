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
  final ApiService _apiService = ApiService();
  late Future<List<VictimReading>> _futureReadings;

  @override
  void initState() {
    super.initState();
    _futureReadings = _apiService.fetchAllReadings();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReadings = _apiService.fetchAllReadings();
    });
  }

  Future<void> _downloadPdf() async {
    // Same host/port as Flask
    final uri =
    Uri.parse('http://127.0.0.1:5001/api/v1/readings/export/pdf');

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF download link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Logging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: FutureBuilder<List<VictimReading>>(
        future: _futureReadings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No readings found'));
          }

          final readings = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: readings.length,
              itemBuilder: (context, index) {
                final r = readings[index];
                return ListTile(
                  title: Text(
                    'Victim: ${r.victimId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Distance: ${r.distanceCm} cm\n'
                        'Lat: ${r.latitude ?? 'N/A'} | '
                        'Lon: ${r.longitude ?? 'N/A'}\n'
                        'Time: ${r.timestamp}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}