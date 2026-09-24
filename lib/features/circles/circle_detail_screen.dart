import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../../core/providers.dart';
import '../../data/models/circle_invite.dart';
import '../../data/models/profile.dart';

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circleAsync = ref.watch(circleProvider(circleId));

    return Scaffold(
      appBar: AppBar(
        title: circleAsync.maybeWhen(
          data: (circle) => Text(circle.name),
          orElse: () => const Text('Circle'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAndShareInvite(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _MembersList(circleId: circleId),
          const SizedBox(height: 24),
          Text('Active invites', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InvitesList(circleId: circleId),
        ],
      ),
    );
  }

  Future<void> _createAndShareInvite(BuildContext context, WidgetRef ref) async {
    final expiry = await showModalBottomSheet<InviteExpiry>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Invite expires after...'),
            ),
            for (final option in InviteExpiry.values)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(option.label),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (expiry == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final invite = await ref.read(circleRepositoryProvider).createInvite(
          circleId: circleId,
          createdBy: userId,
          expiry: expiry,
        );
    ref.invalidate(circleInvitesProvider(circleId));

    if (!context.mounted) return;
    final circleName = ref.read(circleProvider(circleId)).valueOrNull?.name ?? 'my circle';
    await Share.share(
      'Join "$circleName" on Lochness! Open the app, tap Circles > '
      'Join with a code, and enter: ${invite.code}',
    );
  }
}

class _MembersList extends ConsumerWidget {
  const _MembersList({required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(circleMembersProvider(circleId));
    return membersAsync.when(
      data: (members) => Column(
        children: [
          for (final member in members) _MemberTile(member: member),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Could not load members: $error'),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final Profile member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Text(member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase()),
      ),
      title: Text(member.displayName),
    );
  }
}

class _InvitesList extends ConsumerWidget {
  const _InvitesList({required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(circleInvitesProvider(circleId));
    return invitesAsync.when(
      data: (invites) {
        final active = invites.where((invite) => invite.isActive).toList();
        if (active.isEmpty) {
          return const Text('No active invites. Tap "Invite" to create one.');
        }
        return Column(
          children: [
            for (final invite in active) _InviteTile(circleId: circleId, invite: invite),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Could not load invites: $error'),
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.circleId, required this.invite});

  final String circleId;
  final CircleInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiry = invite.expiresAt == null
        ? 'Never expires'
        : 'Expires ${DateFormat.yMMMd().add_jm().format(invite.expiresAt!.toLocal())}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link),
      title: Text(invite.code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      subtitle: Text('$expiry · used ${invite.useCount} time${invite.useCount == 1 ? '' : 's'}'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy code',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.code));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Invite code copied')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Revoke',
            onPressed: () async {
              await ref.read(circleRepositoryProvider).revokeInvite(invite.id);
              ref.invalidate(circleInvitesProvider(circleId));
            },
          ),
        ],
      ),
    );
  }
}
