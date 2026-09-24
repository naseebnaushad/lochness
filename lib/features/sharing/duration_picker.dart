import 'package:flutter/material.dart';

import '../../data/models/location_share.dart';

/// Bottom sheet that lets the user pick how long to share their location for.
/// Returns the chosen [ShareDuration], or null if dismissed.
Future<ShareDuration?> showSharePicker(BuildContext context) {
  return showModalBottomSheet<ShareDuration>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Share your location for...', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final option in ShareDuration.values)
            ListTile(
              leading: Icon(option == ShareDuration.forever ? Icons.all_inclusive : Icons.timer_outlined),
              title: Text(option.label),
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    ),
  );
}
