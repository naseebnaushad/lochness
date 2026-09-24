import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../data/models/live_location.dart';

/// Map view showing the live positions of everyone currently sharing their
/// location with the signed-in user (backed by Supabase Realtime).
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const _defaultCenter = LatLng(37.7749, -122.4194); // fallback: SF

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(visibleLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: locationsAsync.when(
        data: (locations) => _Map(locations: locations),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load locations: $error')),
      ),
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({required this.locations});

  final List<LiveLocation> locations;

  @override
  Widget build(BuildContext context) {
    final center = locations.isNotEmpty
        ? LatLng(locations.first.latitude, locations.first.longitude)
        : MapScreen._defaultCenter;

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.lochness.app',
        ),
        MarkerLayer(
          markers: [
            for (final location in locations)
              Marker(
                point: LatLng(location.latitude, location.longitude),
                width: 44,
                height: 44,
                child: Icon(
                  Icons.location_on,
                  size: 40,
                  color: location.isStale ? Colors.grey : Colors.redAccent,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
