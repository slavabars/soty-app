import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../core/security_limits.dart' show maxDisplayNameLength;
import '../../core/util/random_name.dart' show suggestSotyName;
import 'identity_controller.dart';

/// First-run screen shown when no identity exists yet. There is no account and
/// no server: the only thing the user needs to decide is the display name that
/// is signed into the invite they hand to peers.
class OnboardingScreen extends StatefulWidget {
  final IdentityController identity;
  final VoidCallback onContinue;

  const OnboardingScreen({
    super.key,
    required this.identity,
    required this.onContinue,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  final Random _rng = Random();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rollName();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rollName() {
    setState(() => _name.text = suggestSotyName(random: _rng));
  }

  Future<void> _continue() async {
    if (_busy) return;
    final name = _name.text.trim();
    final clamped = name.length > maxDisplayNameLength
        ? name.substring(0, maxDisplayNameLength)
        : name;
    setState(() => _busy = true);
    await widget.identity.createNew(displayName: clamped);
    if (mounted) {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hive_rounded,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text('Soty', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    SotyL10n.tr(
                      context,
                      'Messaging with no server and no account. Pick a '
                      'display name — it is signed into the invite other '
                      'Soty users import to reach you.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _name,
                    maxLength: maxDisplayNameLength,
                    decoration: InputDecoration(
                      labelText: SotyL10n.tr(context, 'Display name'),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: SotyL10n.tr(context, 'Roll another name'),
                        icon: const Icon(Icons.casino_outlined),
                        onPressed: _busy ? null : _rollName,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(SotyL10n.tr(context, 'Continue')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    SotyL10n.tr(
                      context,
                      'You can change your name later in the identity screen.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
