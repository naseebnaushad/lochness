class GeofenceEvent {
  const GeofenceEvent({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.eventType,
    required this.occurredAt,
  });

  final String id;
  final String placeId;
  final String userId;
  final String eventType; // 'arrival' | 'departure'
  final DateTime occurredAt;

  bool get isArrival => eventType == 'arrival';

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) => GeofenceEvent(
        id: json['id'] as String,
        placeId: json['place_id'] as String,
        userId: json['user_id'] as String,
        eventType: json['event_type'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
      );
}
