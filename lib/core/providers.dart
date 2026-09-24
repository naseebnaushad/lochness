import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/circle.dart';
import '../data/models/circle_invite.dart';
import '../data/models/live_location.dart';
import '../data/models/profile.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/circle_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/place_repository.dart';
import '../services/geofence_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  return CircleRepository(ref.watch(supabaseClientProvider));
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(supabaseClientProvider));
});

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository(ref.watch(supabaseClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final locationTrackingServiceProvider = Provider<LocationTrackingService>((ref) {
  return LocationTrackingService(ref.watch(locationRepositoryProvider));
});

final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  return GeofenceService(
    ref.watch(placeRepositoryProvider),
    ref.watch(notificationServiceProvider),
  );
});

/// Emits the current Supabase auth user, or null when signed out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateProvider); // rebuild on auth changes
  return client.auth.currentUser?.id;
});

final myCirclesProvider = FutureProvider<List<Circle>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return <Circle>[];
  return ref.watch(circleRepositoryProvider).fetchMyCircles(userId);
});

/// Live positions of everyone who is currently sharing with the caller.
final visibleLocationsProvider = StreamProvider<List<LiveLocation>>((ref) {
  return ref.watch(locationRepositoryProvider).watchVisibleLocations();
});

final circleProvider = FutureProvider.family<Circle, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).fetchCircle(circleId);
});

final circleMembersProvider = FutureProvider.family<List<Profile>, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).fetchMembers(circleId);
});

final circleInvitesProvider = FutureProvider.family<List<CircleInvite>, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).fetchInvites(circleId);
});
