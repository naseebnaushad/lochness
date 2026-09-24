import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/circle.dart';
import 'duration_picker.dart';

/// Lets the user pick a circle and a duration, then starts pushing their
/// live location to Supabase and shows a persistent "sharing active" notice.
class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  Future<void> _startShare(BuildContext context, WidgetRef ref, Circle circle) async {
    final duration = await showSharePicker(context);
    if (duration == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final trackingService = ref.read(locationTrackingServiceProvider);
    final hasPermission = await trackingService.ensurePermission();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to share your location.')),
        );
      }
      return;
    }

    await ref.read(locationRepositoryProvider).startShare(
          sharerId: userId,
          circleId: circle.id,
          duration: duration,
        );
    await trackingService.start(userId);
    await ref.read(notificationServiceProvider).showSharingActiveNotification(circleName: circle.name);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing your location with ${circle.name} for ${duration.label.toLowerCase()}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Share location')),
      body: circlesAsync.when(
        data: (circles) {
          if (circles.isEmpty) {
            return const Center(child: Text('Create a circle first to share your location with someone.'));
          }
          return ListView.builder(
            itemCount: circles.length,
            itemBuilder: (context, index) {
              final circle = circles[index];
              return ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(circle.name),
                trailing: FilledButton.tonal(
                  onPressed: () => _startShare(context, ref, circle),
                  child: const Text('Share'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load circles: $error')),
      ),
    );
  }
}
