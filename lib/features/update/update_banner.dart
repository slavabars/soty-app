import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/build_info.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/update/update_controller.dart';
import 'release_notes_view.dart';

/// The startup hint that a newer build exists: the version, a Download (later
/// Install) action, and the two dismissal choices. Renders nothing unless the
/// controller says the banner belongs on screen, so hide/snooze take effect
/// immediately.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.controller,
    this.surface = true,
    this.forceVisible = false,
  });

  final UpdateController controller;

  /// Draws its own tinted surface; off when embedded in a dialog.
  final bool surface;

  /// Ignores the banner's hide/snooze state. The Settings dialog uses it: a
  /// user who dismissed the banner still gets the actions when they open the
  /// update details on purpose.
  final bool forceVisible;

  Future<void> _primary() async {
    if (controller.readyToInstall) {
      await controller.install();
    } else {
      await controller.download();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final release = controller.release;
        if (release == null) return const SizedBox.shrink();
        if (!forceVisible && !controller.bannerVisible) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final downloading = controller.phase == UpdatePhase.downloading;
        final failed = controller.phase == UpdatePhase.failed;
        final body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.system_update_alt,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      SotyL10n.tr(context, 'Version {v} is available', {
                        'v': release.version,
                      }),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (downloading && controller.progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: controller.progress),
              ],
              if (controller.installBlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    SotyL10n.tr(
                      context,
                      'Allow Soty to install apps, then tap Install again.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (failed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    SotyL10n.tr(
                      context,
                      controller.failureKey ?? 'Download failed',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: downloading ? null : () => unawaited(_primary()),
                    child: Text(
                      SotyL10n.tr(
                        context,
                        controller.readyToInstall ? 'Install' : 'Download',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: downloading
                        ? null
                        : () => unawaited(controller.hideBanner()),
                    child: Text(SotyL10n.tr(context, 'Hide')),
                  ),
                  TextButton(
                    onPressed: downloading
                        ? null
                        : () => unawaited(controller.snoozeBanner()),
                    child: Text(SotyL10n.tr(context, 'Remind later')),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!surface) return body;
        return Material(
          color: theme.colorScheme.surfaceContainerHigh,
          child: body,
        );
      },
    );
  }
}

/// Opens the release details: current version, release notes and the same
/// download/install actions the banner offers. Used from the Settings icon.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final notes = controller.release?.notes.trim() ?? '';
      return AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Update available')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SotyL10n.tr(ctx, 'Current version: {v}', {'v': kSotyVersion}),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (!_hasLeadingTitle(notes))
                  Text(
                    SotyL10n.tr(ctx, 'Release notes'),
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                if (!_hasLeadingTitle(notes)) const SizedBox(height: 4),
                ReleaseNotesView(notes),
              ],
              const SizedBox(height: 12),
              UpdateBanner(
                controller: controller,
                surface: false,
                forceVisible: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Close')),
          ),
        ],
      );
    },
  );
}

bool _hasLeadingTitle(String text) {
  final firstNonEmpty = text.split('\n').firstWhere(
    (l) => l.trim().isNotEmpty,
    orElse: () => '',
  );
  final trimmed = firstNonEmpty.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('#')) return true;
  final lower = trimmed.toLowerCase();
  const titles = {'что нового', 'release notes', "what's new", 'whats new'};
  if (titles.contains(lower)) return true;
  return false;
}
