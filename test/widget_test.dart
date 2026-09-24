import 'package:flutter_test/flutter_test.dart';

import 'package:lochness/core/theme/app_theme.dart';
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
}
