import 'dart:async';

import 'package:flutter_mesh_network/flutter_mesh_network.dart';
import 'package:flutter_mesh_network/src/transport/transport.dart' as plugin;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeshNetwork.start', () {
    test('one broken radio does not take the healthy ones down with it',
        () async {
      final healthy = _FakeTransport();
      final mesh = MeshNetwork(
        config: const MeshConfig(enableLogging: false),
        transports: [_FakeTransport(onStart: _radioDown), healthy],
        storage: _FakeStorage(),
      );
      addTearDown(mesh.dispose);

      await mesh.start(userId: 'u', userName: 'me');

      expect(mesh.isRunning, isTrue);
      expect(healthy.started, isTrue);
    });

    test('a transport that reports itself unavailable is simply skipped',
        () async {
      final healthy = _FakeTransport();
      final mesh = MeshNetwork(
        config: const MeshConfig(enableLogging: false),
        transports: [_FakeTransport(onStart: _unavailable), healthy],
        storage: _FakeStorage(),
      );
      addTearDown(mesh.dispose);

      await mesh.start(userId: 'u', userName: 'me');

      expect(mesh.isRunning, isTrue);
      expect(healthy.started, isTrue);
    });

    test('start rethrows and stays stopped when every radio is broken',
        () async {
      final mesh = MeshNetwork(
        config: const MeshConfig(enableLogging: false),
        transports: [
          _FakeTransport(onStart: _radioDown),
          _FakeTransport(onStart: _radioDown),
        ],
        storage: _FakeStorage(),
      );
      addTearDown(mesh.dispose);

      await expectLater(
        mesh.start(userId: 'u', userName: 'me'),
        throwsA(isA<StateError>()),
      );
      expect(mesh.isRunning, isFalse);
    });
  });
}

Future<bool> _radioDown() async => throw StateError('radio down');

Future<bool> _unavailable() async => false;

class _FakeTransport implements plugin.MeshTransport {
  _FakeTransport({Future<bool> Function()? onStart}) : _onStart = onStart;

  final Future<bool> Function()? _onStart;
  final _messages = StreamController<MeshMessage>.broadcast();
  final _nodes = StreamController<MeshNode>.broadcast();

  bool started = false;
  bool active = false;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get isActive => active;

  @override
  Stream<MeshMessage> get messages => _messages.stream;

  @override
  Stream<MeshNode> get nodes => _nodes.stream;

  @override
  Future<bool> start({
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
  }) async {
    final result = await _onStart?.call() ?? true;
    started = true;
    active = result;
    return result;
  }

  @override
  Future<bool> send(MeshMessage message, String peerId) async => false;

  @override
  Future<int> broadcast(MeshMessage message) async => 0;

  @override
  Future<void> updateLocation(double latitude, double longitude) async {}

  @override
  Future<void> stop() async {
    active = false;
  }

  @override
  Future<void> dispose() async {
    active = false;
    await _messages.close();
    await _nodes.close();
  }
}

class _FakeStorage extends MeshStorage {
  _FakeStorage() : super(const MeshConfig(enableLogging: false));

  @override
  Future<List<MeshNode>> getAllNodes() async => [];

  @override
  Future<void> close() async {}
}
