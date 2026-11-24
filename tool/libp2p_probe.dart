import 'dart:typed_data';

// ignore_for_file: avoid_print

import 'package:dart_libp2p/config/config.dart' as p2p;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as lp_ed;
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/network/context.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:dart_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart';
import 'package:dart_libp2p/p2p/transport/tcp_transport.dart';

const String bPeerId =
    '12D3KooWFpaqWUyxwcMTvdQDZbAtuvZfAKguPAo8hMVVSks21RWe';

Future<void> main(List<String> args) async {
  final hostAddr = args.isNotEmpty ? args[0] : '127.0.0.1/tcp/5010';
  final peerIdStr = args.length > 1 ? args[1] : bPeerId;
  final remote = PeerId.decode(peerIdStr);
  final kp = await lp_ed.generateEd25519KeyPair();
  final connMgr = ConnectionManager();
  final rm = ResourceManagerImpl(limiter: FixedLimiter());
  final tcp = TCPTransport(resourceManager: rm, connManager: connMgr);
  final host = await p2p.Libp2p.new_([
    p2p.Libp2p.identity(kp),
    p2p.Libp2p.connManager(connMgr),
    p2p.Libp2p.transport(tcp),
    p2p.Libp2p.listenAddrs([MultiAddr('/ip4/127.0.0.1/tcp/0')]),
  ]);
  await host.start();
  print('OUR PEER ID: ${host.id}');

  try {
    await host.peerStore.addrBook.addAddrs(
      remote,
      [MultiAddr('/ip4/$hostAddr')],
      const Duration(minutes: 5),
    );
    await host.connect(
      AddrInfo(remote, [MultiAddr('/ip4/$hostAddr')]),
      context: Context(timeout: const Duration(seconds: 25)),
    );
    print('CONNECT OK via /ip4/$hostAddr');
  } catch (e) {
    print('CONNECT FAIL via /ip4/$hostAddr: $e');
  }

  try {
    final stream = await host.newStream(
      remote,
      ['/dtm/envelope/2.0.0'],
      Context(timeout: const Duration(seconds: 25)),
    );
    print('STREAM OK');
    await stream.write(Uint8List.fromList('PROBE'.codeUnits));
    await stream.closeWrite();
    print('WROTE PROBE');
  } catch (e) {
    print('STREAM FAIL: $e');
  }

  await host.close();
}