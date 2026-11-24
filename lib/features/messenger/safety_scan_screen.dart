import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/soty_l10n.dart';

/// Reads one QR code and pops it back as raw text.
///
/// Deliberately separate from [ScanQrScreen]: that one treats every decode as a
/// signed invite and imports it, while a safety-number scan must never import
/// anything — it is compared with the locally computed code and thrown away.
class SafetyScanScreen extends StatefulWidget {
  const SafetyScanScreen({super.key});

  @override
  State<SafetyScanScreen> createState() => _SafetyScanScreenState();
}

class _SafetyScanScreenState extends State<SafetyScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handling = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(SotyL10n.tr(context, 'Scan their code'))),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              SotyL10n.tr(
                context,
                'Camera unavailable. Allow camera permission and retry.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          SotyL10n.tr(context, 'Safety number'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
