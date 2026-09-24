import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Bottom-nav shell wrapping the three main tabs: Map, Circles, Share.
/// Also keeps [geofenceNotificationListenerProvider] alive for as long as
/// the signed-in area of the app is on screen.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/map', '/circles', '/share'];

  int _indexForLocation(String location) {
    final index = _tabs.indexWhere((tab) => location.startsWith(tab));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(geofenceNotificationListenerProvider);

    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexForLocation(location),
        onDestinationSelected: (index) => context.go(_tabs[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.share_location_outlined), selectedIcon: Icon(Icons.share_location), label: 'Share'),
        ],
      ),
    );
  }
}
