class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  factory Circle.fromJson(Map<String, dynamic> json) => Circle(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CircleMember {
  const CircleMember({
    required this.circleId,
    required this.userId,
    required this.role,
  });

  final String circleId;
  final String userId;
  final String role;

  bool get isOwner => role == 'owner';

  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
        circleId: json['circle_id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
      );
}
