/// How long a freshly-created invite stays valid before it needs renewing.
enum InviteExpiry {
  sevenDays(Duration(days: 7), '7 days'),
  thirtyDays(Duration(days: 30), '30 days'),
  never(null, 'Never');

  const InviteExpiry(this.duration, this.label);

  final Duration? duration;
  final String label;

  DateTime? expiresAtFrom(DateTime now) =>
      duration == null ? null : now.add(duration!);
}

class CircleInvite {
  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.code,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.maxUses,
    required this.useCount,
  });

  final String id;
  final String circleId;
  final String code;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int? maxUses;
  final int useCount;

  bool get isActive =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now())) &&
      (maxUses == null || useCount < maxUses!);

  factory CircleInvite.fromJson(Map<String, dynamic> json) => CircleInvite(
        id: json['id'] as String,
        circleId: json['circle_id'] as String,
        code: json['code'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String),
        revokedAt: json['revoked_at'] == null
            ? null
            : DateTime.parse(json['revoked_at'] as String),
        maxUses: json['max_uses'] as int?,
        useCount: json['use_count'] as int,
      );
}
