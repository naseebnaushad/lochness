/// Common preset durations offered in the share sheet. `forever` stores a
/// null `expires_at` in Postgres and is only ended by an explicit stop.
enum ShareDuration {
  fifteenMinutes(Duration(minutes: 15), '15 minutes'),
  oneHour(Duration(hours: 1), '1 hour'),
  eightHours(Duration(hours: 8), '8 hours'),
  untilTurnedOff(null, 'Until I turn it off'),
  forever(null, 'Forever');

  const ShareDuration(this.duration, this.label);

  final Duration? duration;
  final String label;

  DateTime? expiresAtFrom(DateTime now) =>
      duration == null ? null : now.add(duration!);
}

class LocationShare {
  const LocationShare({
    required this.id,
    required this.sharerId,
    required this.circleId,
    required this.startedAt,
    this.expiresAt,
    this.stoppedAt,
  });

  final String id;
  final String sharerId;
  final String circleId;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final DateTime? stoppedAt;

  bool get isActive =>
      stoppedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory LocationShare.fromJson(Map<String, dynamic> json) => LocationShare(
        id: json['id'] as String,
        sharerId: json['sharer_id'] as String,
        circleId: json['circle_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String),
        stoppedAt: json['stopped_at'] == null
            ? null
            : DateTime.parse(json['stopped_at'] as String),
      );
}
