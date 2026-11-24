import 'package:dtm_app/core/host/host_link.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart';
import 'package:dtm_app/models/envelope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: a transport whose first attempt failed must report the failure
/// again on the retry instead of claiming a delivery it never made. The old
/// dedup (`if (!_sent.add(id)) return true;`) cached the id on the *first*
/// attempt, so every retry returned success and the message was lost.
void main() {
  final hex32 = List.filled(64, 'a').join();

  Envelope envelope(String id) => Envelope(
    id: id,
    senderPubKey: hex32,
    recipientPubKey: hex32,
    timestamp: 1700000000000,
    ciphertext: 'Y2lwaGVy',
    ephemeralPubKey: hex32,
    signature: List.filled(128, 'b').join(),
  );

  test('send without a connected host reports failure every time', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final transport = HostTransport(
      settings: SettingsDao(db),
      lastTimestamp: () async => 0,
      bootstrapHost: const HostEndpoint(addr: 'ws://127.0.0.1:9/ws'),
    );
    addTearDown(transport.stop);

    // No host is connected, so nothing can be handed off — twice in a row.
    expect(await transport.send(envelope(hex32)), isFalse);
    expect(await transport.send(envelope(hex32)), isFalse);
  });
}
