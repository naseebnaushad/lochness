class Place {
  const Place({
    required this.id,
    required this.circleId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.createdBy,
  });

  final String id;
  final String circleId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;
  final String createdBy;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        circleId: json['circle_id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusM: json['radius_m'] as int,
        createdBy: json['created_by'] as String,
      );
}
