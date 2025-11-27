// lib/models/victim_reading.dart

class VictimReading {
  final int id;
  final String victimId;
  final double distanceCm;
  final double? latitude;
  final double? longitude;
  final String timestamp;

  VictimReading({
    required this.id,
    required this.victimId,
    required this.distanceCm,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  factory VictimReading.fromJson(Map<String, dynamic> json) {
    return VictimReading(
      id: json['id'] is int ? json['id'] as int : (json['id'] as num).toInt(),
      victimId: json['victim_id'] as String,
      distanceCm: (json['distance_cm'] as num).toDouble(),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      timestamp: json['timestamp'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'victim_id': victimId,
      'distance_cm': distanceCm,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }
}