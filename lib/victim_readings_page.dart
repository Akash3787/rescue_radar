import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/victim_reading.dart';
import 'services/api_service.dart';
import 'victim_map_screen.dart';

class VictimReadingsPage extends StatefulWidget {
  const VictimReadingsPage({super.key});

  @override
  State<VictimReadingsPage> createState() => _VictimReadingsPageState();
}

class _VictimReadingsPageState extends State<VictimReadingsPage> {
  final ApiService _apiService = ApiService.forHosted();
  List<VictimReading> _readings = [];
  String? _error;
  bool _loading = false;
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _refresh(); // initial load
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      await _refresh(background: true);
    });
  }

  Future<void> _refresh({bool background = false}) async {
    if (!mounted) return;
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _apiService.fetchAllReadings(page: 1, perPage: 50);
      if (!mounted) return;
      setState(() {
        _readings = data;
        _error = null;
      });
      developer.log('Loaded ${data.length} readings', name: 'VictimReadingsPage');
    } catch (e, st) {
      developer.log('Load error: $e\n$st', name: 'VictimReadingsPage');
      if (!background && mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (!background && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    final baseUrl = _apiService.baseUrl;
    final pdfUrl = "$baseUrl/api/v1/readings/export/pdf";
    final keys = ["secret", _apiService.writeApiKey, "rescue-radar-dev"];

    setState(() {}); // keep it simple (UI shows progress via snackbar)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting PDF download...')),
    );

    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 30);

    for (final key in keys) {
      try {
        final resp = await dio.get<List<int>>(
          pdfUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {"x-api-key": key},
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        if (resp.statusCode == 200 && resp.data != null && resp.data!.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/rescue_readings_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final f = File(path);
          await f.writeAsBytes(resp.data!);
          await OpenFile.open(path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF downloaded & opened')),
          );
          return;
        } else {
          developer.log('PDF attempt key=$key -> ${resp.statusCode}', name: 'VictimReadingsPage');
        }
      } catch (e) {
        developer.log('PDF download error with key=$key: $e', name: 'VictimReadingsPage');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF download failed (see logs)'), backgroundColor: Colors.red),
    );
  }

  void _copySummary(VictimReading v) {
    final text = '''
VICTIM ${v.victimId}
Detected: ${v.detected}
Range: ${v.rangeCm?.toStringAsFixed(1) ?? "N/A"} cm
Angle: ${v.angleDeg?.toStringAsFixed(1) ?? "N/A"}°
Time: ${v.timestamp.toLocal()}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied victim summary')));
  }

  void _openMap(VictimReading v) {
    if (v.latitude == null || v.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS coordinates')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => VictimMapScreen(victim: v)));
  }

  Widget _bigStatusCard() {
    final latest = _readings.isNotEmpty ? _readings.first : null;
    final status = latest == null ? 'No readings' : (latest.detected ? 'PERSON DETECTED' : 'NO PERSON');
    final range = latest?.rangeCm ?? latest?.distanceCm;
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: latest?.detected == true ? Colors.red.shade700 : Colors.green.shade700)),
                    const SizedBox(height: 8),
                    Text(
                      range != null ? '${range.toStringAsFixed(1)} cm' : 'Range: N/A',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (latest != null)
                      Text('Angle: ${latest.angleDeg?.toStringAsFixed(1) ?? "N/A"}°  •  id: ${latest.victimId}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refresh(),
                  tooltip: 'Refresh now',
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _downloadPdf,
                  tooltip: 'Export PDF',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _readingTile(VictimReading r) {
    return ListTile(
      dense: true,
      leading: r.detected
          ? const Icon(Icons.person_search, color: Colors.red)
          : const Icon(Icons.person_off, color: Colors.grey),
      title: Text(r.victimId),
      subtitle: Text('Range: ${r.rangeCm?.toStringAsFixed(1) ?? (r.distanceCm?.toStringAsFixed(1) ?? "N/A")} cm • Angle: ${r.angleDeg?.toStringAsFixed(1) ?? "N/A"}°'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () => _copySummary(r)),
        IconButton(icon: const Icon(Icons.map), onPressed: () => _openMap(r)),
      ]),
      onTap: () {
        // quick inspect
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Victim ${r.victimId}'),
            content: Text('Detected: ${r.detected}\nRange: ${r.rangeCm}\nAngle: ${r.angleDeg}\nTime: ${r.timestamp.toLocal()}'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Rescue Radar';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _downloadPdf),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _bigStatusCard(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _readings.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No victims detected yet', style: TextStyle(fontSize: 18))),
                ],
              )
                  : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _readings.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _readingTile(_readings[i]),
              ),
            ),
          )
        ],
      ),
    );
  }
}