import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/soty_l10n.dart';
import '../messenger/messenger_controller.dart';

/// Camera-based QR scanner. Any valid decode is treated as a signed invite
/// and, when it verifies, [Navigator.pop]s `true` after importing the peer.
class ScanQrScreen extends StatefulWidget {
  final MessengerController messenger;

  const ScanQrScreen({super.key, required this.messenger});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;
  String _lastRaw = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty || raw == _lastRaw) return;
    _lastRaw = raw;
    _handling = true;
    final imported = await widget.messenger.importInvite(raw);
    if (!mounted) return;
    if (imported) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SotyL10n.tr(context, 'Invite rejected'))),
      );
      setState(() => _handling = false);
    }
  }

  Widget _errorBuilder(BuildContext context, MobileScannerException error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            SotyL10n.tr(
              context,
              'Camera unavailable. Allow camera permission and retry.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _controller.start(),
            child: Text(SotyL10n.tr(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SotyL10n.tr(context, 'Scan QR code'))),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: _errorBuilder,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          SotyL10n.tr(context, 'Point the camera at a Soty contact QR code.'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}