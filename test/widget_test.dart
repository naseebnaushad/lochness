import 'package:flutter_test/flutter_test.dart';

import 'package:lochness/core/theme/app_theme.dart';
import 'package:lochness/data/models/circle_invite.dart';
import 'package:lochness/data/models/location_share.dart';

void main() {
  test('AppTheme builds light and dark themes', () {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(AppTheme.dark().brightness.name, 'dark');
  });

  test('ShareDuration.forever never expires', () {
    expect(ShareDuration.forever.expiresAtFrom(DateTime.now()), isNull);
  });

  test('ShareDuration.oneHour expires an hour later', () {
    final now = DateTime(2024, 1, 1, 12);
    final expiresAt = ShareDuration.oneHour.expiresAtFrom(now);
    expect(expiresAt, DateTime(2024, 1, 1, 13));
  });

  test('InviteExpiry.never never expires', () {
    expect(InviteExpiry.never.expiresAtFrom(DateTime.now()), isNull);
  });

  test('InviteExpiry.sevenDays expires a week later', () {
    final now = DateTime(2024, 1, 1);
    expect(InviteExpiry.sevenDays.expiresAtFrom(now), DateTime(2024, 1, 8));
  });

  CircleInvite invite({DateTime? expiresAt, DateTime? revokedAt, int? maxUses, int useCount = 0}) {
    return CircleInvite(
      id: 'invite-1',
      circleId: 'circle-1',
      code: 'ABCD1234',
      createdBy: 'user-1',
      createdAt: DateTime(2024, 1, 1),
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      maxUses: maxUses,
      useCount: useCount,
    );
  }

  test('CircleInvite.isActive is true with no expiry, revocation, or use cap', () {
    expect(invite().isActive, isTrue);
  });

  test('CircleInvite.isActive is false once revoked', () {
    expect(invite(revokedAt: DateTime.now()).isActive, isFalse);
  });

  test('CircleInvite.isActive is false once expired', () {
    expect(invite(expiresAt: DateTime.now().subtract(const Duration(days: 1))).isActive, isFalse);
  });

  test('CircleInvite.isActive is false once the use cap is reached', () {
    expect(invite(maxUses: 3, useCount: 3).isActive, isFalse);
  });

  test('CircleInvite.isActive is true below the use cap', () {
    expect(invite(maxUses: 3, useCount: 2).isActive, isTrue);
  });
}
