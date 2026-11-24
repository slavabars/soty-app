import 'dart:io';

import 'package:dtm_app/core/host/host_link.dart';
import 'package:dtm_app/core/storage/database.dart';
import 'package:dtm_app/core/storage/settings_dao.dart';
import 'package:dtm_app/core/transport/host/host_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostTransport keepalive', () {
    test('keepAliveInterval defaults to a 25s ping', () {
      expect(keepAliveInterval, const Duration(seconds: 25));
    });

    test('the websocket factory is handed the keepalive interval', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final dao = SettingsDao(db);

      String? seenUrl;
      Duration? seenKeepAlive;
      final transport = HostTransport(
        settings: dao,
        lastTimestamp: () async => 0,
        bootstrapHost: const HostEndpoint(
          addr: 'ws://127.0.0.1:9/ws',
          edPubKey: '',
        ),
        // A connecting failure is all the test needs: it still proves the
        // transport calls its websocket factory with the ping interval, and
        // the graceful reconnect path cancels cleanly on stop.
        webSocketConnector: (url, keepAlive) {
          seenUrl = url;
          seenKeepAlive = keepAlive;
          return Future<WebSocket>.error(
            const WebSocketException('relay down'),
            StackTrace.current,
          );
        },
      );
      addTearDown(transport.stop);

      await transport.start(
        myEdPubKey: 'a' * 64,
        myXPubKey: 'a' * 64,
        displayName: 'Test',
      );
      expect(seenUrl, 'ws://127.0.0.1:9/ws');
      expect(seenKeepAlive, keepAliveInterval);

      await transport.stop();
    });
  });
}