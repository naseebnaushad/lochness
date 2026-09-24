import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import '../../data/models/place.dart';

/// Manages the geofenced places for a circle (e.g. "Home", "School"). Each
/// place is saved from the device's current position rather than a map pin
/// drop, so setting up "Home" means standing at home and tapping Add.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key, required this.circleId});

  final String circleId;

  Future<void> _addPlace(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to add a place.')),
        );
      }
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not get your location: $e')));
      }
      return;
    }

    if (!context.mounted) return;
    final result = await showDialog<_NewPlaceResult>(
      context: context,
      builder: (context) => const _AddPlaceDialog(),
    );
    if (result == null) return;

    await ref.read(placeRepositoryProvider).createPlace(
          circleId: circleId,
          name: result.name,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusM: result.radiusM,
          createdBy: userId,
        );
    ref.invalidate(placesProvider(circleId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placesProvider(circleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlace(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add current location'),
      ),
      body: placesAsync.when(
        data: (places) => places.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No places yet. Stand somewhere like home or school and tap '
                    '"Add current location" so this circle gets notified when '
                    'someone arrives or leaves.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  return _PlaceTile(circleId: circleId, place: place);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load places: $error')),
      ),
    );
  }
}

class _PlaceTile extends ConsumerWidget {
  const _PlaceTile({required this.circleId, required this.place});

  final String circleId;
  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.place_outlined),
      title: Text(place.name),
      subtitle: Text('Notifies within ${place.radiusM} m'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete place',
        onPressed: () async {
          await ref.read(placeRepositoryProvider).deletePlace(place.id);
          ref.invalidate(placesProvider(circleId));
        },
      ),
    );
  }
}

class _NewPlaceResult {
  const _NewPlaceResult({required this.name, required this.radiusM});
  final String name;
  final int radiusM;
}

class _AddPlaceDialog extends StatefulWidget {
  const _AddPlaceDialog();

  @override
  State<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<_AddPlaceDialog> {
  final _nameController = TextEditingController();
  double _radiusM = 150;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Home'),
          ),
          const SizedBox(height: 16),
          Text('Notify within ${_radiusM.round()} m'),
          Slider(
            value: _radiusM,
            min: 50,
            max: 500,
            divisions: 9,
            label: '${_radiusM.round()} m',
            onChanged: (value) => setState(() => _radiusM = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, _NewPlaceResult(name: name, radiusM: _radiusM.round()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
