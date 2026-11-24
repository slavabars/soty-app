import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/background/background_service.dart';
import '../../core/backup/backup_crypto.dart';
import '../../core/backup/backup_files.dart';
import '../../core/backup/backup_service.dart';
import '../../core/build_info.dart';
import '../../core/host/host_link.dart';
import '../../core/i18n/app_prefs.dart';
import '../../core/i18n/soty_l10n.dart';
import '../../core/invite_link.dart';
import '../../core/links.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/security_limits.dart'
    show
        maxActivePeersCeiling,
        maxActivePeersDefault,
        maxAppLockPasswordLength,
        maxFrameBytes,
        maxHosts,
        minAppLockPasswordLength,
        retentionOptionsDays;
import '../../core/storage/identity_dao.dart';
import '../../core/storage/settings_dao.dart';
import '../../core/transport/host/host_transport.dart';
import '../../core/transport/mesh/mesh_transport.dart';
import '../../core/transport/p2p/p2p_transport.dart';
import '../../core/update/update_controller.dart';
import '../identity/identity_controller.dart';
import '../messenger/messenger_controller.dart';
import '../update/release_notes_view.dart';
import '../update/update_banner.dart';
import 'app_lock_controller.dart';
import 'backup_dialogs.dart';
import 'my_qr_screen.dart';
import 'scan_qr_screen.dart';

/// Settings: share/import your contact via QR and configure the app lock
/// (password + biometrics).
class SettingsScreen extends StatefulWidget {
  final IdentityController identity;
  final MessengerController messenger;
  final AppLockController appLock;

  /// Wiring the settings screen to the live transports when present; it keeps
  /// working standalone (tests) when they are null.
  final SettingsDao? settingsDao;
  final P2PTransport? p2pTransport;
  final MeshTransport? meshTransport;
  final AppPrefs prefs;

  /// Live notifier, so a user whose banners never appear can see whether the
  /// platform blocked them instead of guessing.
  final NotificationService? notifications;

  /// Drives the "new version" icon in the app bar and the update row; `null`
  /// on builds without an update feed.
  final UpdateController? update;

  /// Backup/restore wiring; `null` builds the real service from the live
  /// database, tests inject their own.
  final BackupService? backup;

  /// Called after a successful restore, so the app can rebuild every
  /// controller around the new identity. Without it the UI only reports
  /// success and the caller is responsible for the restart.
  final Future<void> Function()? onIdentityRestored;

  /// Opens the legal pages; tests inject a spy, a device uses the browser.
  final Future<bool> Function(Uri)? legalOpener;

  const SettingsScreen({
    super.key,
    required this.identity,
    required this.messenger,
    required this.appLock,
    required this.prefs,
    this.settingsDao,
    this.p2pTransport,
    this.meshTransport,
    this.notifications,
    this.update,
    this.backup,
    this.onIdentityRestored,
    this.legalOpener,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _changingLock = false;
  StreamSubscription<void>? _sub;
  Timer? _statsTimer;

  /// Live libp2p connection count. Kept in a notifier so the once-a-second
  /// refresh repaints one subtitle instead of the whole settings screen.
  final ValueNotifier<int> _liveConnections = ValueNotifier<int>(0);
  NotificationAvailability _notifications = NotificationAvailability.unknown;
  bool? _ignoringBatteryOptimizations;

  AppLockController get _appLock => widget.appLock;

  late final BackupService _backup = widget.backup ??
      BackupService(
        identityDao: IdentityDao(widget.messenger.dao.attachedDatabase),
        peerDao: widget.messenger.peerDao,
      );

  @override
  void initState() {
    super.initState();
    _sub = widget.messenger.onChange.listen((_) {
      if (mounted) setState(() {});
    });
    widget.update?.addListener(_onUpdateChanged);
    unawaited(_probeNotifications());
    unawaited(_probeBackground());
    // The live-connection gauge is owned by libp2p, not by the messenger, so it
    // has no change stream: poll it once a second while the screen is up.
    _pollConnections();
    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollConnections(),
    );
  }

  void _pollConnections() {
    if (!mounted) return;
    _liveConnections.value = widget.p2pTransport?.activeConnections ?? 0;
  }

  void _onUpdateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.update?.removeListener(_onUpdateChanged);
    _sub?.cancel();
    _statsTimer?.cancel();
    _liveConnections.dispose();
    super.dispose();
  }

  /// One line for the About card: what the update check currently knows.
  String _updateStatus() {
    final update = widget.update;
    if (update == null) return '';
    final release = update.release;
    if (update.phase == UpdatePhase.checking) {
      return SotyL10n.tr(context, 'Checking…');
    }
    if (release != null) {
      return SotyL10n.tr(context, 'Version {v} is available', {
        'v': release.version,
      });
    }
    if (update.phase == UpdatePhase.failed) {
      return SotyL10n.tr(context, 'Could not check for updates');
    }
    if (update.phase == UpdatePhase.upToDate) {
      return SotyL10n.tr(context, 'You have the latest version');
    }
    return SotyL10n.tr(context, 'Current version: {v}', {'v': kSotyVersion});
  }

  /// Forces a check (the startup one runs at most daily) and opens the release
  /// details when something newer is there.
  Future<void> _checkForUpdates() async {
    final update = widget.update;
    if (update == null) return;
    await update.check();
    if (!mounted) return;
    if (update.hasUpdate) {
      await showUpdateDialog(context, update);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SotyL10n.tr(
            context,
            update.phase == UpdatePhase.failed
                ? 'Could not check for updates'
                : 'You have the latest version',
          ),
        ),
      ),
    );
  }

  Future<void> _showMyQr() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyQrScreen(identity: widget.identity),
      ),
    );
  }

  Future<void> _scanQr() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ScanQrScreen(messenger: widget.messenger),
      ),
    );
    if (imported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SotyL10n.tr(context, 'Contact added from QR code')),
        ),
      );
    }
  }

  Future<void> _copyInvite() async {
    final invite = await widget.identity.invitePayload();
    if (invite == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: invite));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SotyL10n.tr(context, 'Invite copied to clipboard')),
        ),
      );
    }
  }

  Future<void> _copyInviteLink() async {
    final invite = await widget.identity.invitePayload();
    if (invite == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: InviteLink.encode(invite)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SotyL10n.tr(context, 'Invite link copied to clipboard'),
          ),
        ),
      );
    }
  }

  HostTransport? _hostTransport() {
    for (final transport in widget.messenger.transports) {
      if (transport is HostTransport) return transport;
    }
    return null;
  }

  Future<void> _probeNotifications() async {
    final service = widget.notifications;
    if (service == null) {
      if (mounted) {
        setState(() => _notifications = NotificationAvailability.unsupported);
      }
      return;
    }
    final state = await service.availability();
    if (mounted) setState(() => _notifications = state);
  }

  /// Reads whether the system lets the app run unrestricted so the Settings
  /// row shows the truth instead of a silent guess.
  Future<void> _probeBackground() async {
    final ignoring = await BackgroundService().isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _ignoringBatteryOptimizations = ignoring);
  }

  /// Applies the user's choice to run (or not) in the background, restarting
  /// the foreground service when it was off and is now toggled on.
  Future<void> _setBackground(bool value) async {
    await widget.prefs.setBackground(value);
    if (value) {
      await BackgroundService().start();
    } else {
      await BackgroundService().stop();
    }
  }

  /// The battery row opens the user-initiated "no restrictions" dialog, then
  /// re-reads the state so the subtitle reflects the outcome.
  Future<void> _openBatteryOptimization() async {
    await BackgroundService().requestIgnoreBatteryOptimizations();
    await _probeBackground();
  }

  String _batteryStatus() {
    return switch (_ignoringBatteryOptimizations) {
      true => SotyL10n.tr(context, 'No restrictions'),
      false => SotyL10n.tr(context, 'Restricted by the system'),
      null => SotyL10n.tr(context, 'Checking…'),
    };
  }

  String _notificationStatus() {
    return switch (_notifications) {
      NotificationAvailability.ready =>
        SotyL10n.tr(context, 'Enabled on this device'),
      NotificationAvailability.blocked =>
        SotyL10n.tr(context, 'Blocked by the system'),
      NotificationAvailability.unavailable => SotyL10n.tr(
          context,
          'Not available: {reason}',
          {'reason': _notificationReason()},
        ),
      NotificationAvailability.unsupported =>
        SotyL10n.tr(context, 'Not supported on this platform'),
      NotificationAvailability.unknown =>
        SotyL10n.tr(context, 'Checking notification support…'),
    };
  }

  String _notificationReason() {
    final error = widget.notifications?.lastError ?? '';
    return error.isEmpty ? '—' : error;
  }

  IconData get _notificationIcon => switch (_notifications) {
        NotificationAvailability.ready => Icons.notifications_outlined,
        NotificationAvailability.blocked => Icons.notifications_off_outlined,
        NotificationAvailability.unavailable => Icons.error_outline,
        NotificationAvailability.unsupported => Icons.desktop_access_disabled,
        NotificationAvailability.unknown => Icons.notifications_none,
      };

  Future<void> _sendTestNotification() async {
    final service = widget.notifications;
    if (service == null) return;
    final result = await service.sendTest(
      title: SotyL10n.tr(context, 'Soty'),
      body: SotyL10n.tr(context, 'Test notification'),
    );
    await _probeNotifications();
    if (!mounted) return;
    final message = switch (result) {
      NotificationTestResult.sent =>
        SotyL10n.tr(context, 'Test notification sent'),
      NotificationTestResult.blocked =>
        SotyL10n.tr(context, 'Notifications are blocked by the system'),
      NotificationTestResult.unavailable => SotyL10n.tr(
          context,
          'Test notification failed: {reason}',
          {'reason': _notificationReason()},
        ),
      NotificationTestResult.unsupported =>
        SotyL10n.tr(context, 'Not supported on this platform'),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openNotificationSettings() async {
    await widget.notifications?.openSystemSettings();
    await _probeNotifications();
  }

  Future<void> _addHost() async {
    final host = _hostTransport();
    if (host == null) return;
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _AddHostDialog(),
    );
    if (input == null || !mounted) return;
    final HostEndpoint? endpoint;
    try {
      endpoint = _parseHostInput(input);
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Invalid host link'))),
        );
      }
      return;
    }
    final added = await host.addHost(endpoint);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SotyL10n.tr(
            context,
            added ? 'Relay host added' : 'Relay host list is full (max {max})',
            {'max': '$maxHosts'},
          ),
        ),
      ),
    );
    setState(() {});
  }

  HostEndpoint _parseHostInput(String input) {
    if (input.startsWith('soty://')) {
      final endpoint = HostLink.fromRoute(input);
      if (endpoint == null) {
        throw const FormatException('Not a host link');
      }
      return endpoint;
    }
    if (!input.startsWith('ws://') && !input.startsWith('wss://')) {
      throw const FormatException('Enter a ws:// URL or a soty:// link');
    }
    return HostEndpoint(addr: input);
  }

Future<void> _removeHost(HostEndpoint endpoint) async {
    final host = _hostTransport();
    if (host == null) return;
    await host.removeHost(endpoint.addr);
  }

  Future<void> _pickRelayMode() async {
    final host = _hostTransport();
    final current = host?.relayMode ?? widget.prefs.relayMode;
    final selected = await showDialog<RelayMode>(
      context: context,
      builder: (_) => _RelayModeDialog(current: current),
    );
    if (selected == null || !mounted) return;
    await widget.prefs.setRelayMode(selected);
    await host?.setRelayMode(selected);
  }

  Future<void> _toggleAppLock(bool enable) async {
    if (_changingLock) return;
    if (enable) {
      final password = await _promptSetPassword();
      if (password == null || !mounted) return;
      setState(() => _changingLock = true);
      try {
        await _appLock.setPassword(password);
      } catch (_) {
        // Length was validated by the dialog; unreachable in practice.
      } finally {
        if (mounted) setState(() => _changingLock = false);
      }
      return;
    }
    final password = await _promptEnterPassword(
      title: SotyL10n.tr(context, 'Disable app lock'),
      subtitle: SotyL10n.tr(context, 'Enter your current password.'),
    );
    if (password == null || !mounted) return;
    setState(() => _changingLock = true);
    final disabled = await _appLock.disable(password);
    if (mounted) {
      setState(() => _changingLock = false);
      if (!disabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Incorrect password'))),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final current = await _promptEnterPassword(
      title: SotyL10n.tr(context, 'Current password'),
      subtitle: SotyL10n.tr(context, 'Confirm your current password.'),
    );
    if (current == null || !mounted) return;
    final next = await _promptSetPassword();
    if (next == null || !mounted) return;
    setState(() => _changingLock = true);
    try {
      await _appLock.changePassword(current: current, next: next);
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SotyL10n.tr(context, 'Incorrect password'))),
        );
      }
    } finally {
      if (mounted) setState(() => _changingLock = false);
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      if (!await _appLock.biometricAuth.isSupported()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                SotyL10n.tr(
                  context,
                  'Biometrics are not available on this device',
                ),
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final password = await _promptEnterPassword(
        title: SotyL10n.tr(context, 'Enable fingerprint unlock'),
        subtitle: SotyL10n.tr(context, 'Enter your password to confirm.'),
      );
      if (password == null || !mounted) return;
      try {
        await _appLock.setBiometricEnabled(
          enabled: true,
          confirmPassword: password,
        );
      } on ArgumentError {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(SotyL10n.tr(context, 'Incorrect password'))),
          );
        }
      }
      if (mounted) setState(() {});
      return;
    }
    await _appLock.setBiometricEnabled(enabled: false);
    if (mounted) setState(() {});
  }

  Future<void> _setActivePeers() async {
    final p2p = widget.p2pTransport;
    if (p2p == null) return;
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _ActivePeersDialog(initial: p2p.maxActivePeers),
    );
    if (value == null || !mounted) return;
    p2p.maxActivePeers = value;
    await widget.settingsDao?.set('soty.maxActivePeers', '$value');
    if (mounted) setState(() {});
  }

  Future<void> _pickRetention() async {
    final previous = widget.prefs.retentionDays;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Keep messages')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SotyL10n.tr(
                  ctx,
                  'How long your own conversations stay on this device. '
                  'Envelopes you only relay for others are always pruned '
                  'after 30 days (capped at 10 GB).',
                ),
              ),
              const SizedBox(height: 8),
              for (final days in retentionOptionsDays)
                ListTile(
                  leading: Icon(
                    days == previous ? Icons.check : null,
                  ),
                  title: Text(_retentionLabel(ctx, days)),
                  onTap: () => Navigator.of(ctx).pop(days),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
        ],
      ),
    );
    if (selected == null || !mounted || selected == previous) return;
    await widget.prefs.setRetentionDays(selected);
    await widget.messenger.reapplyRetention(retentionDays: selected);
    if (mounted) setState(() {});
  }

  static String _retentionLabel(BuildContext context, int days) {
    if (days == 0) return SotyL10n.tr(context, 'Forever');
    return SotyL10n.tr(context, '{n} days', {'n': '$days'});
  }

  Future<String?> _promptSetPassword() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _SetPasswordDialog(
        title: SotyL10n.tr(ctx, 'Set app lock password'),
        confirmLabel: SotyL10n.tr(ctx, 'Enable lock'),
        minLength: minAppLockPasswordLength,
        maxLength: maxAppLockPasswordLength,
      ),
    );
  }

  Future<String?> _promptEnterPassword({
    required String title,
    required String subtitle,
  }) {
    final confirmLabel = 'Confirm';
    return showDialog<String>(
      context: context,
      builder: (ctx) => _EnterPasswordDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: SotyL10n.tr(ctx, confirmLabel),
        maxLength: maxAppLockPasswordLength,
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final locale = await showDialog<Locale>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Language')),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final supported in supportedLocales)
                ListTile(
                  leading: Icon(
                    supported == widget.prefs.locale ? Icons.check : null,
                  ),
                  title: Text(_languageName(supported)),
                  onTap: () => Navigator.of(ctx).pop(supported),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
        ],
      ),
    );
    if (locale != null) {
      await widget.prefs.setLocale(locale);
    }
  }

  Future<void> _pickTheme() async {
    final theme = await showDialog<SotyTheme>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(SotyL10n.tr(ctx, 'Theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in SotyTheme.values)
              ListTile(
                leading: Icon(
                  option == widget.prefs.theme ? Icons.check : null,
                ),
                title: Text(SotyL10n.tr(ctx, _themeName(option))),
                onTap: () => Navigator.of(ctx).pop(option),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(SotyL10n.tr(ctx, 'Cancel')),
          ),
        ],
      ),
    );
    if (theme != null) {
      await widget.prefs.setTheme(theme);
    }
  }

  static String _languageName(Locale locale) =>
      SotyL10n.languageName(locale);

  static String _themeName(SotyTheme theme) => switch (theme) {
    SotyTheme.system => 'System',
    SotyTheme.light => 'Light',
    SotyTheme.dark => 'Dark',
  };

  void _backupSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _exportBackup() async {
    final password = await showBackupPasswordDialog(context, confirm: true);
    if (password == null || !mounted) return;
    Directory? temp;
    try {
      // The streaming format writes the ciphertext into a temp file, so a
      // 1 GiB history never has to exist as one Dart string plus one byte
      // array at the same time.
      temp = await Directory.systemTemp.createTemp('soty_export');
      final path = '${temp.path}/backup.soty';
      await _backup.exportBackupToFile(path: path, password: password);
      final location = await BackupFiles.savePath(
        path,
        name: BackupFiles.defaultName(),
      );
      if (!mounted || location == null) return;
      _backupSnack(
        SotyL10n.tr(context, 'Backup created: {path}', {'path': location}),
      );
    } catch (_) {
      if (!mounted) return;
      _backupSnack(SotyL10n.tr(context, 'Backup failed'));
    } finally {
      await temp?.delete(recursive: true).catchError((_) => temp!);
    }
  }

  Future<void> _restoreBackup() async {
    if (!BackupFiles.canPick) {
      _backupSnack(
        SotyL10n.tr(
          context,
          'Picking a file is not supported on this platform',
        ),
      );
      return;
    }
    final String? path;
    try {
      path = await BackupFiles.pickPath();
    } catch (_) {
      if (!mounted) return;
      _backupSnack(SotyL10n.tr(context, 'Backup failed'));
      return;
    }
    if (path == null || !mounted) return;
    try {
      final password = await showBackupPasswordDialog(context, confirm: false);
      if (password == null || !mounted) return;
      final confirmed = await showRestoreConfirmation(context);
      if (!confirmed || !mounted) return;
      await _backup.restoreBackupFromFile(
        path: path,
        password: password,
        replaceExisting: true,
      );
      await widget.onIdentityRestored?.call();
      if (!mounted) return;
      _backupSnack(SotyL10n.tr(context, 'Backup restored'));
    } on BackupAuthFailure {
      if (!mounted) return;
      _backupSnack(
        SotyL10n.tr(context, 'Wrong password or damaged backup file'),
      );
    } on FormatException {
      if (!mounted) return;
      _backupSnack(
        SotyL10n.tr(context, 'Wrong password or damaged backup file'),
      );
    } catch (_) {
      if (!mounted) return;
      _backupSnack(SotyL10n.tr(context, 'Backup failed'));
    } finally {
      final file = File(path);
      if (await file.exists()) {
        await file.delete().catchError((_) => file);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = widget.prefs;
    String tr(String key, [Map<String, Object> args = const {}]) =>
        SotyL10n.tr(context, key, args);
    final lockEnabled = _appLock.isEnabled;
    final hostTransport = _hostTransport();
    final hosts = hostTransport?.visibleHosts ?? const <HostEndpoint>[];
    final relayMode = hostTransport?.relayMode ?? widget.prefs.relayMode;
    final connected = hostTransport
        ?.connectedHosts.map((h) => h.addr)
        .toSet() ??
    const <String>{};
    final activePeersCount =
        widget.p2pTransport?.maxActivePeers ?? maxActivePeersDefault;
    final peers = widget.messenger.peers.values;
    final registeredPeers = peers.length;
    final onlinePeers = peers.where((p) => p.online).length;
    final meshStatus = widget.meshTransport?.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Settings')),
        actions: [
          if (widget.update?.hasUpdate ?? false)
            IconButton(
              key: const ValueKey('updateIcon'),
              tooltip: tr('Update available'),
              icon: const Icon(Icons.system_update_alt),
              onPressed: () =>
                  unawaited(showUpdateDialog(context, widget.update!)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('Contact'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_2_outlined),
                  title: Text(tr('My QR code')),
                  subtitle: Text(tr('Show this code so others can add you.')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_showMyQr()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_outlined),
                  title: Text(tr('Scan QR code')),
                  subtitle: Text(
                    tr('Add a contact by scanning their code.'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_scanQr()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(tr('Copy invite')),
                  subtitle: Text(tr('Paste the invite instead of a QR.')),
                  onTap: () => unawaited(_copyInvite()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(tr('Copy invite link')),
                  subtitle: Text(
                    tr('A soty:// link that opens Soty to add you.'),
                  ),
                  onTap: () => unawaited(_copyInviteLink()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Security'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: Text(tr('App lock')),
                  subtitle: Text(tr('Require a password to open Soty.')),
                  value: lockEnabled,
                  onChanged: _changingLock
                      ? null
                      : (v) => unawaited(_toggleAppLock(v)),
                ),
                if (lockEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: Text(tr('Change password')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changingLock
                        ? null
                        : () => unawaited(_changePassword()),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(tr('Fingerprint unlock')),
                    subtitle: Text(
                      tr('Unlock with biometrics instead of typing the '
                          'password.'),
                    ),
                    value: _appLock.isBiometricEnabled,
                    onChanged: (v) => unawaited(_toggleBiometric(v)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Notifications'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(_notificationIcon),
                  title: Text(tr('Message notifications')),
                  subtitle: Text(_notificationStatus()),
                ),
                if (widget.notifications?.canOpenSystemSettings ??
                    false) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text(tr('Open system notification settings')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(_openNotificationSettings()),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(tr('Send test notification')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_sendTestNotification()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Network'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(tr('Peers in network')),
                  subtitle: Text(
                    tr('{n} registered · {online} online', {
                      'n': '$registeredPeers',
                      'online': '$onlinePeers',
                    }),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(tr('Active connections')),
                  subtitle: ValueListenableBuilder<int>(
                    valueListenable: _liveConnections,
                    builder: (context, live, _) => Text(
                      tr('{n} of {max} direct peers in exchange', {
                        'n': '$live',
                        'max': '$activePeersCount',
                      }),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bluetooth_connected_outlined),
                  title: Text(tr('Mesh (BLE/Wi-Fi Direct)')),
                  subtitle: Text(
                    meshStatus == null
                        ? tr('Unavailable')
                        : meshStatus.running
                            ? tr('{n} nodes in range',
                                {'n': '${meshStatus.nodeCount}'})
                            : (meshStatus.permissions?.ok ?? true)
                                ? tr('Off')
                                : tr('Permission required'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(tr('Relay hosts')),
                  subtitle: Text(
                    tr('{n} visible · {connected} connected', {
                      'n': '${hosts.length}',
                      'connected': '${connected.length}',
                    }),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(tr('Active peers limit')),
                  subtitle: Text(
                    tr('Keep at most {n} direct peers connected.', {
                      'n': '$activePeersCount',
                    }),
                  ),
                  trailing: const Icon(Icons.tune),
                  onTap: () => unawaited(_setActivePeers()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Backup'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: Text(tr('Export backup')),
                  subtitle: Text(
                    tr(
                      'Encrypted file with your identity, contacts and '
                      'messages.',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_exportBackup()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(tr('Restore backup')),
                  subtitle: Text(
                    tr(
                      'Replace the identity, contacts and messages on this '
                      'device from a backup file.',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_restoreBackup()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Relay hosts'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                for (final (index, host) in hosts.indexed) ...[
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(
                      host.addr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      connected.contains(host.addr)
                          ? tr('Connected')
                          : tr('Offline'),
                    ),
                    trailing: IconButton(
                      tooltip: tr('Remove host'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => unawaited(_removeHost(host)),
                    ),
                  ),
                  if (index != hosts.length - 1) const Divider(height: 1),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_alt),
                  title: Text(tr('Relay failover')),
                  subtitle: Text(
                    tr(relayMode == RelayMode.auto
                        ? 'Automatic fallback'
                        : 'Only configured relays'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_pickRelayMode()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_link),
                  title: Text(tr('Add relay host')),
                  subtitle: Text(tr('Paste a ws:// URL or a soty:// host link.')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_addHost()),
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.near_me_outlined),
                  title: Text(tr('Tracker discovery')),
                  subtitle: Text(
                    tr('Peers found via trackers: {n}.', {
                      'n': '${hostTransport?.peersImported ?? 0}',
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Messages'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.keyboard_return),
                  title: Text(tr('Send with Enter')),
                  subtitle: Text(
                    tr('Press Enter to send; turn it off to add a new line.'),
                  ),
                  value: prefs.sendOnEnter,
                  onChanged: (value) => unawaited(prefs.setSendOnEnter(value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.done_all),
                  title: Text(tr('Read receipts')),
                  subtitle: Text(
                    tr(
                      'Send read receipts so others know when you have '
                      'read their messages.',
                    ),
                  ),
                  value: prefs.readReceipts,
                  onChanged: (value) =>
                      unawaited(prefs.setReadReceipts(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Storage'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(tr('Keep messages')),
                  subtitle: Text(
                    _retentionLabel(context, prefs.retentionDays),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_pickRetention()),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.chat_bubble_outline),
                  title: Text(tr('Save sent messages')),
                  subtitle: Text(
                    tr(
                      'Keep my sent messages on this device so they stay '
                      'readable after restart',
                    ),
                  ),
                  value: prefs.storeOutgoing,
                  onChanged: (value) =>
                      unawaited(prefs.setStoreOutgoing(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Background'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.swap_vertical_circle_outlined),
                  title: Text(tr('Work in background')),
                  subtitle: Text(
                    tr(
                      'Keep mesh and relays alive while the app is not in '
                      'the chat',
                    ),
                  ),
                  value: prefs.background,
                  onChanged: (value) => unawaited(_setBackground(value)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.battery_saver),
                  title: Text(tr('Battery optimization')),
                  subtitle: Text(_batteryStatus()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_openBatteryOptimization()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('Appearance'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(tr('Language')),
                  subtitle: Text(_languageName(prefs.locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_pickLanguage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(tr('Theme')),
                  subtitle: Text(tr(_themeName(prefs.theme))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_pickTheme()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('About'), style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(tr('Version')),
                  subtitle: const Text(kSotyVersion),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_showVersionInfo()),
                ),
                if (widget.update != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('updateRow'),
                    leading: const Icon(Icons.system_update_alt),
                    title: Text(tr('Check for updates')),
                    subtitle: Text(_updateStatus()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(_checkForUpdates()),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(tr('Source and releases')),
                  subtitle: const Text(kSotyGitUrl),
                  trailing: const Icon(Icons.copy_outlined),
                  onTap: () => unawaited(_copyGitLink()),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('privacyRow'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(tr('Privacy policy')),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => unawaited(_openLegal(_privacyUri())),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('termsRow'),
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(tr('Terms of use')),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => unawaited(_openLegal(_termsUri())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Copies the git link rather than opening a browser: the app ships no
  /// url_launcher, and a messenger that works offline should not need a
  /// platform browser to show you where its release lives.
  Future<void> _copyGitLink() async {
    await Clipboard.setData(
      const ClipboardData(text: kSotyGitUrl),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(SotyL10n.tr(context, 'Link copied to clipboard')),
      ),
    );
  }

  Uri _privacyUri() => privacyUri(
        languageCode: Localizations.localeOf(context).languageCode,
      );

  Uri _termsUri() => termsUri(
        languageCode: Localizations.localeOf(context).languageCode,
      );

  /// Opens a legal page in the platform browser, falling back to copying the
  /// link when no browser can handle it.
  Future<void> _openLegal(Uri uri) async {
    final opener = widget.legalOpener ??
        (target) => launchUrl(target, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await opener(uri);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(SotyL10n.tr(context, 'Link copied'))),
    );
  }

  Future<void> _showVersionInfo() async {
    final controller = widget.update;
    var notes = await controller?.notesForRunningVersion();
    if (notes != null) notes = notes.trim();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(SotyL10n.tr(ctx, 'Version')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(kSotyVersion),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    SotyL10n.tr(ctx, 'Release notes'),
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  ReleaseNotesView(notes),
                ],
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
}

/// Copies a 1..50 slider over the direct-peer pool cap.
class _ActivePeersDialog extends StatefulWidget {
  final int initial;
  const _ActivePeersDialog({required this.initial});

  @override
  State<_ActivePeersDialog> createState() => _ActivePeersDialogState();
}

class _ActivePeersDialogState extends State<_ActivePeersDialog> {
  late double _value = widget.initial.toDouble();
  late int _selection = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(SotyL10n.tr(context, 'Active peers limit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SotyL10n.tr(
              context,
              'How many direct peers the device keeps available at once. '
              'Raise it for dense meshes; lower it to save battery and '
              'traffic.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_selection',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Slider(
            value: _value,
            min: 1,
            max: maxActivePeersCeiling.toDouble(),
            divisions: maxActivePeersCeiling - 1,
            label: '$_selection',
            onChanged: (v) {
              setState(() {
                _value = v;
                _selection = v.round();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SotyL10n.tr(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          child: Text(SotyL10n.tr(context, 'Apply')),
        ),
      ],
    );
  }
}

/// Collects a new password plus a confirmation field.
class _SetPasswordDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final int minLength;
  final int maxLength;

  const _SetPasswordDialog({
    required this.title,
    required this.confirmLabel,
    required this.minLength,
    required this.maxLength,
  });

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;
    if (password.length < widget.minLength ||
        password.length > widget.maxLength) {
      setState(
        () => _error = SotyL10n.tr(
          context,
          'Use {min}–{max} characters',
          {'min': '${widget.minLength}', 'max': '${widget.maxLength}'},
        ),
      );
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = SotyL10n.tr(context, 'Passwords do not match'));
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: widget.maxLength,
            decoration: InputDecoration(
              labelText: SotyL10n.tr(context, 'Password'),
            ),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: widget.maxLength,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: SotyL10n.tr(context, 'Repeat password'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SotyL10n.tr(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Collects a new relay host address.
/// Picks how the device handles relays learned from tracker-capable hosts.
class _RelayModeDialog extends StatelessWidget {
  final RelayMode current;
  const _RelayModeDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    String tr(String key) => SotyL10n.tr(context, key);
    return SimpleDialog(
      title: Text(tr('Relay failover')),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(RelayMode.manual),
          child: ListTile(
            title: Text(tr('Only configured relays')),
            subtitle: Text(tr('Never use relays learned from trackers.')),
            trailing: current == RelayMode.manual
                ? const Icon(Icons.check)
                : null,
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(RelayMode.auto),
          child: ListTile(
            title: Text(tr('Automatic fallback')),
            subtitle: Text(
              tr(
                'Use relays learned from hosts when the configured ones '
                'are unreachable.',
              ),
            ),
            trailing: current == RelayMode.auto
                ? const Icon(Icons.check)
                : null,
          ),
        ),
      ],
    );
  }
}

class _AddHostDialog extends StatefulWidget {
  const _AddHostDialog();

  @override
  State<_AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends State<_AddHostDialog> {
  final TextEditingController _host = TextEditingController();

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _host.text.trim();
    if (input.isEmpty) return;
    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(SotyL10n.tr(context, 'Add relay host')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SotyL10n.tr(
              context,
              'A relay host stores only encrypted envelopes. Anyone running '
              'one can see who talks to whom, so use hosts you trust.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: maxFrameBytes,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: SotyL10n.tr(context, 'Host'),
              hintText: SotyL10n.tr(
                context,
                'ws://host:port/ws or soty://host?addr=…',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SotyL10n.tr(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(SotyL10n.tr(context, 'Add')),
        ),
      ],
    );
  }
}

/// Collects a single secret (used to confirm the current password).
class _EnterPasswordDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final int maxLength;

  const _EnterPasswordDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.maxLength,
  });

  @override
  State<_EnterPasswordDialog> createState() => _EnterPasswordDialogState();
}

class _EnterPasswordDialogState extends State<_EnterPasswordDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.subtitle),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: widget.maxLength,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: SotyL10n.tr(context, 'Password'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(SotyL10n.tr(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
