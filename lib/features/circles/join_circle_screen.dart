import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Lets the user redeem an invite code shared by a circle owner/member.
/// The code itself carries all the info the server needs (see
/// `accept_circle_invite` in supabase/migrations/0002_circle_invites.sql) —
/// no need to know anyone's user id.
class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final circle = await ref.read(circleRepositoryProvider).joinByCode(code);
      ref.invalidate(myCirclesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Joined "${circle.name}"!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('not found')) return 'That code doesn\'t match any invite.';
    if (message.contains('revoked')) return 'This invite has been revoked.';
    if (message.contains('expired')) return 'This invite has expired.';
    if (message.contains('use limit')) return 'This invite has already been used up.';
    return 'Could not join: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a circle')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the invite code someone shared with you',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.bold),
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'ABCD1234',
                  ),
                  onSubmitted: (_) => _join(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSubmitting ? null : _join,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
