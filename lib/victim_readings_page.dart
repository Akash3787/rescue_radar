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

class _VictimReadingsPageState extends State<VictimReadingsPage>
    with TickerProviderStateMixin {
  late ApiService _apiService;
  late Future<List<VictimReading>> _futureReadings;
  String? _error;
  bool _isDownloading = false;
  bool _isDarkMode = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  Future<void> _downloadPdf() async {
    // Backend URL from API service
    const baseUrl = "https://web-production-87279.up.railway.app";
    final pdfUrl = "$baseUrl/api/v1/readings/export/pdf";
    
    // Railway uses "secret" as WRITE_API_KEY (verified with curl test)
    // Try multiple API keys in order - "secret" first since that's what Railway uses
    final apiKeys = [
      "secret",                  // Railway environment value (verified working)
      _apiService.writeApiKey,   // Current API service key (usually "secret")
      "rescue-radar-dev",        // Backend default (fallback)
    ];
    
    developer.log('📥 Starting PDF download from: $pdfUrl');
    developer.log('🔑 Trying API keys: ${apiKeys.join(", ")}');
    
    setState(() => _isDownloading = true);
    
    try {
      // Determine download directory based on platform
      String filePath;
      if (Platform.isMacOS) {
        // Use macOS temp directory directly (avoid path_provider platform channel issue)
        final tempPath = Platform.environment['TMPDIR'] ?? '/tmp';
        filePath = "$tempPath/victim_readings_${DateTime.now().millisecondsSinceEpoch}.pdf";
        developer.log('📁 Using macOS temp path: $filePath');
      } else if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          throw Exception("Storage permission denied");
        }
        final dir = await getApplicationDocumentsDirectory();
        filePath = "${dir.path}/victim_readings_${DateTime.now().millisecondsSinceEpoch}.pdf";
      } else {
        final dir = await getApplicationDocumentsDirectory();
        filePath = "${dir.path}/victim_readings_${DateTime.now().millisecondsSinceEpoch}.pdf";
      }

      // For Web: show message
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("⚠️ Web download not supported. Please use desktop/mobile app."),
              backgroundColor: _isDarkMode ? Colors.orange.shade800 : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final dio = Dio();
      // Add timeout
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      
      Exception? lastError;
      int? lastStatusCode;
      bool success = false;
      
      // Try each API key
      for (final apiKey in apiKeys) {
        try {
          developer.log('🔑 Trying API key: $apiKey');
          
          final resp = await dio.get<List<int>>(
            pdfUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {"x-api-key": apiKey},
              validateStatus: (status) {
                // Don't throw on client errors (4xx), only server errors (5xx)
                return status != null && status < 500;
              },
            ),
          );
          
          developer.log('📡 Response status: ${resp.statusCode}');
          developer.log('📦 Response data size: ${resp.data?.length ?? 0} bytes');

          if (resp.statusCode == 200 && resp.data != null && resp.data!.isNotEmpty) {
            // Success! Save and open file
            final file = File(filePath);
            await file.writeAsBytes(resp.data!);
            developer.log('✅ PDF saved to: $filePath');
            
            // Open the file
            if (Platform.isMacOS) {
              await Process.run('open', [filePath]);
            } else {
              await OpenFile.open(file.path);
            }
            
            success = true;
            break;
          } else if (resp.statusCode == 401) {
            // Unauthorized - try next key
            lastError = Exception('Unauthorized (401) - API key "$apiKey" rejected');
            lastStatusCode = 401;
            developer.log('❌ Unauthorized with key: $apiKey');
            continue;
          } else if (resp.statusCode == 404) {
            lastError = Exception('PDF endpoint not found (404)');
            lastStatusCode = 404;
            developer.log('❌ Endpoint not found');
            continue;
          } else if (resp.statusCode != null) {
            lastError = Exception('Server returned status ${resp.statusCode}');
            lastStatusCode = resp.statusCode;
            developer.log('❌ Server error: ${resp.statusCode}');
            continue;
          } else {
            lastError = Exception('Invalid response: no status code');
            developer.log('❌ Invalid response');
            continue;
          }
        } catch (e) {
          developer.log('❌ Exception with key "$apiKey": $e');
          if (e is DioException) {
            if (e.response != null) {
              lastStatusCode = e.response!.statusCode;
              lastError = Exception('HTTP ${e.response!.statusCode}: ${e.response!.statusMessage}');
            } else if (e.type == DioExceptionType.connectionTimeout) {
              lastError = Exception('Connection timeout - check your internet');
            } else if (e.type == DioExceptionType.receiveTimeout) {
              lastError = Exception('Receive timeout - server took too long');
            } else {
              lastError = Exception('Network error: ${e.message}');
            }
          } else {
            lastError = Exception('Download failed: $e');
          }
          continue;
        }
      }
      
      if (!success) {
        String errorMsg = 'Failed to download PDF';
        if (lastStatusCode == 401) {
          errorMsg = 'Authentication failed. Check Railway WRITE_API_KEY environment variable.\nTried keys: ${apiKeys.join(", ")}';
        } else if (lastStatusCode == 404) {
          errorMsg = 'PDF endpoint not found. Verify backend URL: $pdfUrl';
        } else if (lastStatusCode != null) {
          errorMsg = 'Server error: HTTP $lastStatusCode';
        } else if (lastError != null) {
          errorMsg = lastError.toString();
        }
        throw Exception(errorMsg);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ PDF downloaded and opened"),
            backgroundColor: _isDarkMode ? Colors.green.shade800 : Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('❌ PDF download ERROR: $e');
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.length > 150) {
          errorMsg = errorMsg.substring(0, 150) + '...';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ PDF failed: $errorMsg"),
            backgroundColor: _isDarkMode ? Colors.red.shade800 : Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                developer.log('Full error: $e');
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _copyVictimInfo(VictimReading victim) {
    final formattedTimestamp = victim.timestamp?.toString() ?? "N/A";
    final lat = victim.latitude?.toStringAsFixed(6) ?? "N/A";
    final lon = victim.longitude?.toStringAsFixed(6) ?? "N/A";

    final fullInfo = """
🆘 VICTIM LOCATION DETECTED 🆘
═══════════════════════════════
📅 Time: $formattedTimestamp
🆔 ID: ${victim.victimId}
📏 Distance: ${victim.distanceCm.toStringAsFixed(1)} cm
🌍 Lat: $lat
🌐 Lon: $lon
═══════════════════════════════
    """.trim();

    Clipboard.setData(ClipboardData(text: fullInfo));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("📋 Copied COMPLETE victim info!"),
        backgroundColor: _isDarkMode ? Colors.green.shade700 : Colors.green,
      ),
    );
  }

  Future<void> _openInGoogleMaps(VictimReading victim) async {
    if (victim.latitude == null || victim.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("❌ No GPS coordinates available for this victim"),
          backgroundColor: _isDarkMode ? Colors.red.shade800 : Colors.red,
        ),
      );
      return;
    }

    // Google Maps URL format: https://www.google.com/maps?q=lat,lon
    // This works on all platforms (web, mobile, desktop)
    final lat = victim.latitude!;
    final lon = victim.longitude!;
    final urlString = 'https://www.google.com/maps?q=$lat,$lon';
    final url = Uri.parse(urlString);

    try {
      // macOS-specific handling: use 'open' command directly
      // This avoids the platform channel issue with url_launcher
      if (Platform.isMacOS) {
        final result = await Process.run('open', [urlString]);
        if (result.exitCode == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("🗺️ Opening location in Google Maps..."),
                backgroundColor: _isDarkMode ? Colors.blue.shade800 : Colors.blue,
              ),
            );
          }
          return;
        } else {
          throw Exception('Failed to open URL: ${result.stderr}');
        }
      }

      // For other platforms, use url_launcher
      // Skip canLaunchUrl check on macOS as it can fail
      bool canLaunch = true;
      if (!Platform.isMacOS && !kIsWeb) {
        try {
          canLaunch = await canLaunchUrl(url);
        } catch (e) {
          developer.log('canLaunchUrl check failed, proceeding anyway: $e');
          canLaunch = true; // Proceed anyway
        }
      }

      if (canLaunch || kIsWeb) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("🗺️ Opening location in Google Maps..."),
              backgroundColor: _isDarkMode ? Colors.blue.shade800 : Colors.blue,
            ),
          );
        }
      } else {
        throw Exception('Could not launch Google Maps');
      }
    } catch (e) {
      developer.log('❌ Google Maps launch ERROR: $e');
      if (mounted) {
        String errorMsg = e.toString();
        // Clean up error message for display
        if (errorMsg.contains('PlatformException')) {
          errorMsg = 'Failed to open maps. Please check your system settings.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ $errorMsg"),
            backgroundColor: _isDarkMode ? Colors.red.shade800 : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Table Helper Methods
  DataColumn _buildDataColumn(String label, IconData icon, bool isDark) {
    return DataColumn(
      label: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataCell _buildTimeCell(String time, bool isDark) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time.length > 20 ? "${time.substring(0, 17)}..." : time,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  DataCell _buildTextCell(String text, bool isDark) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  DataCell _buildDistanceCell(String distance, bool isDark) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Text(
          distance,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.cyan.shade400 : Colors.green.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  DataCell _buildCoordCell(String coord, bool isDark) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          coord,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  DataCell _buildActionCell(VictimReading victim, bool isDark, Function(VictimReading) onCopy) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy button
            IconButton(
              icon: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? LinearGradient(
                        colors: [
                          Colors.blue.shade700,
                          Colors.purple.shade600,
                          Colors.blue.shade800.withOpacity(0.8),
                        ],
                        begin: Alignment(-0.5 + _shimmerAnimation.value * 1.5, -0.5),
                        end: Alignment(0.5 - _shimmerAnimation.value * 1.5, 0.5),
                      )
                          : LinearGradient(
                        colors: [
                          Colors.blue.shade500,
                          Colors.blue.shade600,
                          Colors.blue.shade400,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black45 : Colors.black26).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.copy, size: 20, color: Colors.white),
                  );
                },
              ),
              onPressed: () => onCopy(victim),
              tooltip: "Copy victim details",
            ),
            const SizedBox(width: 8),
            // Map button
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.red.shade700, Colors.orange.shade600]
                        : [Colors.red.shade500, Colors.orange.shade400],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black45 : Colors.black26).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.map, size: 20, color: Colors.white),
              ),
              onPressed: () => _openInGoogleMaps(victim),
              tooltip: "Open in Google Maps",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [const Color(0xFF121212), const Color(0xFF1A1A1A)]
              : [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 80,
                color: _isDarkMode ? Colors.orange.shade300 : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load data from backend',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Try reloading the page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: _isDarkMode ? Colors.white70 : Colors.black54
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text('Reload', style: TextStyle(fontSize: 16)),
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: _isDarkMode ? Colors.blue.shade700 : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: _isDarkMode ? 16 : 8,
        shadowColor: _isDarkMode ? Colors.black54 : Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: _isDarkMode ? const Color(0xFF424242) : color.withOpacity(0.18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: _isDarkMode ? Colors.white : Colors.black87, size: 40),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                    fontSize: 16,
                    color: _isDarkMode ? Colors.white70 : Colors.black87
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
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
        : (readings.map((e) => e.distanceCm).reduce((a, b) => a + b) / total);
    final gpsCount = readings.where((r) => r.latitude != null).length;
    final gpsPct = total == 0 ? 0 : ((gpsCount / total) * 100).round();

    final headerColor = _isDarkMode ? Colors.blue.shade900 : Colors.blue.shade700;

    return RefreshIndicator(
      onRefresh: _load,
      color: _isDarkMode ? Colors.blue.shade400 : Colors.blue,
      backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Metrics Row
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _metricCard("Victims", "$total", Icons.person, Colors.blue),
                  const SizedBox(width: 16),
                  _metricCard("Avg Dist (cm)", avgDist.toStringAsFixed(1), Icons.straighten, Colors.green),
                  const SizedBox(width: 16),
                  _metricCard("GPS %", "$gpsPct%", Icons.location_on, Colors.orange),
                ],
              ),
            ),

            // Header


            // Enhanced Table
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDarkMode
                      ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
                      : [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isDarkMode ? const Color(0xFF000000).withOpacity(0.5) : Colors.black.withOpacity(0.15),
                    blurRadius: _isDarkMode ? 25 : 12,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width * 0.95,
                  ),
                  child: DataTable(
                    headingRowHeight: 70,
                    dataRowHeight: 76,
                    headingRowColor: WidgetStateProperty.all(
                      _isDarkMode
                          ? const Color(0xFF1E3A8A).withOpacity(0.95)
                          : Colors.blue.shade700,
                    ),
                    border: _isDarkMode
                        ? TableBorder(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      horizontalInside: const BorderSide(color: Color(0xFF404040), width: 1),
                      verticalInside: const BorderSide(color: Color(0xFF404040), width: 1),
                      bottom: const BorderSide(color: Color(0xFF404040)),
                    )
                        : null,
                    columns: [
                      _buildDataColumn("TIME", Icons.access_time, _isDarkMode),
                      _buildDataColumn("VICTIM ID", Icons.person, _isDarkMode),
                      _buildDataColumn("DIST (cm)", Icons.straighten, _isDarkMode),

// With these:
                      _buildDataColumn("LATITUDE", Icons.location_on, _isDarkMode),
                      _buildDataColumn("LONGITUDE", Icons.location_on, _isDarkMode),

                      _buildDataColumn("ACTIONS", Icons.more_horiz, _isDarkMode),
                    ],
                    rows: readings.asMap().entries.map((entry) {
                      final index = entry.key;
                      final r = entry.value;
                      final isEvenRow = index.isEven;
                      final rowBg = _isDarkMode
                          ? (isEvenRow ? const Color(0xFF212121) : const Color(0xFF2A2A2A))
                          : (isEvenRow ? Colors.blue.shade500 : Colors.white);

                      return DataRow(
                        color: WidgetStateProperty.all(rowBg),
                        cells: [
                          _buildTimeCell(r.timestamp?.toString() ?? "N/A", _isDarkMode),
                          _buildTextCell(r.victimId, _isDarkMode),
                          _buildDistanceCell(r.distanceCm.toStringAsFixed(1), _isDarkMode),
                          _buildCoordCell(r.latitude?.toStringAsFixed(4) ?? "N/A", _isDarkMode),
                          _buildCoordCell(r.longitude?.toStringAsFixed(4) ?? "N/A", _isDarkMode),
                          _buildActionCell(r, _isDarkMode, _copyVictimInfo),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const title = "Data Logging";

    return Theme(
      data: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: _isDarkMode ? 0 : 6,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Go Back',
          ),
          title: const Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? [Colors.grey.shade900, Colors.grey.shade800]
                    : [Colors.blue.shade700, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Switch(
                value: _isDarkMode,
                onChanged: (_) => _toggleTheme(),
                activeColor: Colors.blue.shade600,
                activeTrackColor: Colors.blue.shade400,
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.grey.shade400,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: _isDownloading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.download, color: Colors.white, size: 28),
                tooltip: "Download PDF Report",
                onPressed: _isDownloading ? null : _downloadPdf,
              ),
            ),
          ],
        ),
        body: _error != null
            ? _buildErrorCard()
            : FutureBuilder<List<VictimReading>>(
          future: _futureReadings,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode
                        ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                        : [Colors.white, Colors.grey.shade50],
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _isDarkMode ? Colors.blue.shade400 : Colors.blue,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorCard();
            }
            final data = snapshot.data!;
            if (data.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDarkMode
                        ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                        : [Colors.white, Colors.grey.shade50],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: _isDarkMode ? Colors.white70 : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No victims detected yet",
                        style: TextStyle(
                          fontSize: 20,
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reload Data", style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDarkMode ? Colors.blue.shade700 : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _buildList(data);
          },
        ),
      ),
    );
  }
}
