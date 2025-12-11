import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as latlng;

import 'models/victim_reading.dart';

class VictimMapScreen extends StatefulWidget {
  final VictimReading victim;

  const VictimMapScreen({
    super.key,
    required this.victim,
  });

  @override
  State<VictimMapScreen> createState() => _VictimMapScreenState();
}

class _VictimMapScreenState extends State<VictimMapScreen> {
  gm.GoogleMapController? _mapController;
  late gm.LatLng _victimLocation;
  late latlng.LatLng _victimLocationLatLng;
  bool _isDarkMode = false;
  late final bool _useGoogleMaps;

  @override
  void initState() {
    super.initState();
    _useGoogleMaps = defaultTargetPlatform != TargetPlatform.macOS;
    if (widget.victim.latitude != null && widget.victim.longitude != null) {
      _victimLocation = gm.LatLng(
        widget.victim.latitude!,
        widget.victim.longitude!,
      );
      _victimLocationLatLng = latlng.LatLng(
        widget.victim.latitude!,
        widget.victim.longitude!,
      );
    } else {
      // Default location if no GPS (shouldn't happen, but fallback)
      _victimLocation = const gm.LatLng(0.0, 0.0);
      _victimLocationLatLng = const latlng.LatLng(0.0, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF1A1D23) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.teal[800],
        title: Text(
          "Victim Location: ${widget.victim.victimId}",
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showVictimInfo,
            tooltip: "Victim Details",
          ),
        ],
      ),
      body: Stack(
        children: [
          _useGoogleMaps ? _buildGoogleMap() : _buildFlutterMapFallback(),
          // Info card overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              color: _isDarkMode ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Victim Location",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow("ID", widget.victim.victimId),
                    _buildInfoRow(
                      "Distance",
                      "${widget.victim.distanceCm.toStringAsFixed(1)} cm",
                    ),
                    _buildInfoRow(
                      "Latitude",
                      widget.victim.latitude?.toStringAsFixed(6) ?? "N/A",
                    ),
                    _buildInfoRow(
                      "Longitude",
                      widget.victim.longitude?.toStringAsFixed(6) ?? "N/A",
                    ),
                    if (widget.victim.temperatureC != null)
                      _buildInfoRow(
                        "Temperature",
                        "${widget.victim.temperatureC!.toStringAsFixed(1)} °C",
                      ),
                    if (widget.victim.humidityPct != null)
                      _buildInfoRow(
                        "Humidity",
                        "${widget.victim.humidityPct!.toStringAsFixed(1)}%",
                      ),
                    _buildInfoRow(
                      "Time",
                      _formatTimestamp(widget.victim.timestamp),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerMapOnVictim,
        backgroundColor: Colors.teal[800],
        child: const Icon(Icons.my_location, color: Colors.white),
        tooltip: "Center on Victim",
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} "
        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
  }

  void _centerMapOnVictim() {
    if (_useGoogleMaps) {
      _mapController?.animateCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(
            target: _victimLocation,
            zoom: 17.0,
          ),
        ),
      );
    }
  }

  void _showVictimInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Victim Details",
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogRow("Victim ID", widget.victim.victimId),
              _buildDialogRow("Distance", "${widget.victim.distanceCm.toStringAsFixed(1)} cm"),
              _buildDialogRow(
                "Latitude",
                widget.victim.latitude?.toStringAsFixed(6) ?? "N/A",
              ),
              _buildDialogRow(
                "Longitude",
                widget.victim.longitude?.toStringAsFixed(6) ?? "N/A",
              ),
              if (widget.victim.temperatureC != null)
                _buildDialogRow(
                  "Temperature",
                  "${widget.victim.temperatureC!.toStringAsFixed(1)} °C",
                ),
              if (widget.victim.humidityPct != null)
                _buildDialogRow(
                  "Humidity",
                  "${widget.victim.humidityPct!.toStringAsFixed(1)}%",
                ),
              if (widget.victim.gasPpm != null)
                _buildDialogRow(
                  "Gas",
                  "${widget.victim.gasPpm!.toStringAsFixed(0)} ppm",
                ),
              _buildDialogRow("Timestamp", widget.victim.timestamp.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Widget _buildGoogleMap() {
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: _victimLocation,
        zoom: 15.0,
      ),
      markers: {
        gm.Marker(
          markerId: const gm.MarkerId('victim_location'),
          position: _victimLocation,
          infoWindow: gm.InfoWindow(
            title: 'Victim: ${widget.victim.victimId}',
            snippet: 'Distance: ${widget.victim.distanceCm.toStringAsFixed(1)} cm',
          ),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
        ),
      },
      onMapCreated: (gm.GoogleMapController controller) {
        _mapController = controller;
      },
      myLocationButtonEnabled: true,
      myLocationEnabled: true,
      mapType: gm.MapType.normal,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
    );
  }

  Widget _buildFlutterMapFallback() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _victimLocationLatLng,
        initialZoom: 15.0,
        interactionOptions: const InteractionOptions(
          flags: ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.rescue_radar',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _victimLocationLatLng,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          ],
        ),
      ],
    );
  }

}
