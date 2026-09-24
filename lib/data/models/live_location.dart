class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyM,
    this.headingDeg,
    this.speedMS,
  });

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracyM;
  final double? headingDeg;
  final double? speedMS;

  bool get isStale => DateTime.now().difference(recordedAt) > const Duration(minutes: 10);

  factory LiveLocation.fromJson(Map<String, dynamic> json) => LiveLocation(
        userId: json['user_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        headingDeg: (json['heading'] as num?)?.toDouble(),
        speedMS: (json['speed_m_s'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toUpsertJson() => {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'heading': headingDeg,
        'speed_m_s': speedMS,
        'recorded_at': recordedAt.toIso8601String(),
      };
}
