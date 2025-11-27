// lib/victim_readings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/victim_reading.dart';
import 'services/api_service.dart';

class VictimReadingsPage extends StatefulWidget {
  const VictimReadingsPage({super.key});

  @override
  State<VictimReadingsPage> createState() => _VictimReadingsPageState();
}

class _VictimReadingsPageState extends State<VictimReadingsPage> {
  final ApiService _apiService = ApiService(
    forcedBase: 'http://172.20.45.32:5001',
  );
  late Future<List<VictimReading>> _futureReadings;

  // Analytics values (updated after load)
  int _uniqueVictimsToday = 0;
  double _avgDistanceToday = 0.0;
  double _gpsPercentToday = 0.0;

  @override
  void initState() {
    super.initState();
    // quick hint: replace with your server IP found above
    _futureReadings = ApiService(lanHints: ['192.168.0.200:5001']).fetchAllReadings();
  }

  Future<List<VictimReading>> _loadAndCompute() async {
    final data = await _apiService.fetchAllReadings();
    final analytics = _computeAnalyticsInternal(data);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _uniqueVictimsToday = analytics['unique'];
          _avgDistanceToday = analytics['avg'];
          _gpsPercentToday = analytics['gps'];
        });
      }
    });
    return data;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReadings = _loadAndCompute();
    });
  }

  Map<String, dynamic> _computeAnalyticsInternal(List<VictimReading> data) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayData = data.where((r) {
      final ts = DateTime.tryParse(r.timestamp);
      if (ts == null) return false;
      final local = ts.toLocal();
      return local.isAfter(todayStart) && local.isBefore(todayEnd);
    }).toList();

    final unique = <String>{};
    for (final r in todayData) unique.add(r.victimId);

    double avg = 0.0;
    if (todayData.isNotEmpty) {
      avg = todayData.map((r) => r.distanceCm).reduce((a, b) => a + b) / todayData.length;
    }

    final gpsCount = todayData.where((r) => r.latitude != null && r.longitude != null).length;
    final gpsPercent = todayData.isEmpty ? 0.0 : (gpsCount / todayData.length) * 100.0;

    return {
      'unique': unique.length,
      'avg': double.parse(avg.toStringAsFixed(1)),
      'gps': double.parse(gpsPercent.toStringAsFixed(1)),
    };
  }

  Future<void> _downloadPdf() async {
    final uri = Uri.parse("http://127.0.0.1:5001/api/v1/readings/export/pdf");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open PDF")),
        );
      }
    }
  }

  Future<void> _openMap(double? lat, double? lon) async {
    if (lat == null || lon == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No GPS coordinates")),
        );
      }
      return;
    }
    final uri = Uri.parse("https://www.google.com/maps?q=$lat,$lon");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _analyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 5),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _readingCard(VictimReading r) {
    final ts = DateTime.tryParse(r.timestamp);
    final formattedTime = ts != null ? ts.toLocal().toString().split('.').first : r.timestamp;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blueGrey,
            child: Text(r.victimId.length > 6 ? r.victimId.substring(r.victimId.length - 4).toUpperCase() : r.victimId.toUpperCase(), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(r.victimId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.7))),
                  ],
                ),
                const SizedBox(height: 8),
                Chip(label: Text("${r.distanceCm.toStringAsFixed(1)} cm", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.teal),
                const SizedBox(height: 8),
                if (r.latitude != null && r.longitude != null)
                  GestureDetector(onTap: () => _openMap(r.latitude, r.longitude), child: Row(children: [const Icon(Icons.location_pin, size: 18, color: Colors.redAccent), const SizedBox(width: 6), Text("${r.latitude!.toStringAsFixed(4)}, ${r.longitude!.toStringAsFixed(4)}", style: const TextStyle(fontSize: 13))]))
                else
                  Text("No GPS", style: TextStyle(color: Colors.grey.withOpacity(0.7))),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(tooltip: "Copy JSON", icon: const Icon(Icons.copy), onPressed: () {
                final json = {'victim_id': r.victimId, 'distance_cm': r.distanceCm, 'latitude': r.latitude, 'longitude': r.longitude, 'timestamp': r.timestamp}.toString();
                Clipboard.setData(ClipboardData(text: json));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied JSON")));
              }),
              IconButton(tooltip: "Open in Maps", icon: const Icon(Icons.map), onPressed: () => _openMap(r.latitude, r.longitude)),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0E13) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Data Logging"),
        actions: [
          IconButton(icon: const Icon(Icons.download), tooltip: 'Export PDF', onPressed: _downloadPdf),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<VictimReading>>(
        future: _futureReadings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));

          final data = snapshot.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                child: Row(
                  children: [
                    _analyticsCard(title: "Unique Victims", value: "$_uniqueVictimsToday", icon: Icons.people, accent: Colors.cyanAccent),
                    _analyticsCard(title: "Avg Distance (cm)", value: "${_avgDistanceToday.toStringAsFixed(1)}", icon: Icons.straighten, accent: Colors.tealAccent),
                    _analyticsCard(title: "GPS % Today", value: "${_gpsPercentToday.toStringAsFixed(1)}%", icon: Icons.location_on, accent: Colors.redAccent),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: RefreshIndicator(onRefresh: _refresh, child: ListView.builder(padding: const EdgeInsets.only(bottom: 20), itemCount: data.length, itemBuilder: (_, i) => _readingCard(data[i])))),
            ],
          );
        },
      ),
    );
  }
}