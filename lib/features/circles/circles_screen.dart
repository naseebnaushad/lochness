import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  Future<void> _createCircle(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New circle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Family'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(circleRepositoryProvider).createCircle(name: name, ownerId: userId);
    ref.invalidate(myCirclesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your circles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createCircle(context, ref),
        child: const Icon(Icons.add),
      ),
      body: circlesAsync.when(
        data: (circles) => circles.isEmpty
            ? const Center(child: Text('No circles yet. Tap + to create one.'))
            : ListView.builder(
                itemCount: circles.length,
                itemBuilder: (context, index) {
                  final circle = circles[index];
                  return ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(circle.name),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load circles: $error')),
      ),
    );
  }
}
