import 'dart:async';

import 'package:dtm_app/core/notifications/chat_notifications.dart';
import 'package:dtm_app/core/notifications/notification_service.dart';
import 'package:dtm_app/core/sync/envelope_processor.dart';
import 'package:dtm_app/models/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements NotificationService {
  final List<({String peerPubKey, String title, String body})> shown = [];
  final List<String> cancelled = [];
  final StreamController<String> _taps =
      StreamController<String>.broadcast();

  @override
  bool get canOpenSystemSettings => false;

  @override
  Stream<String> get onNotificationTap => _taps.stream;

  @override
  Future<void> initialize({String? actionLabel}) async {}

  @override
  Future<void> showChatMessage({
    required String peerPubKey,
    required String title,
    required String body,
  }) async {
    shown.add((peerPubKey: peerPubKey, title: title, body: body));
  }

  @override
  Future<void> cancelChatMessage(String peerPubKey) async {
    cancelled.add(peerPubKey);
  }

  @override
  Future<NotificationAvailability> availability() async =>
      NotificationAvailability.ready;

  @override
  Future<NotificationTestResult> sendTest({
    required String title,
    required String body,
  }) async =>
      NotificationTestResult.sent;

  @override
  String get lastError => '';

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> dispose() async => _taps.close();

  void tap(String peerPubKey) => _taps.add(peerPubKey);
}

DecryptedMessage _message({String? sender, String plaintext = 'hello'}) =>
    DecryptedMessage(
      id: 'f' * 64,
      senderPubKey: sender ?? 'e' * 64,
      recipientPubKey: 'r' * 64,
      timestamp: 0,
      plaintext: plaintext,
    );

void main() {
  late _FakeService service;
  late StreamController<DecryptedMessage> inbox;
  late ChatNotifications notifications;
  final resolvedKey = 'x' * 64;
  final resolvedTitle = 'Zora';
  final otherKey = 'w' * 64;
  final groupMemberKey = 'b2' * 32;
  final groupCorr = 'c3' * 32;
  final groupId = 'a1' * 32;
  final groupTitle = 'Crew';
  var groupKnown = true;
  String? visible;

  setUp(() {
    visible = null;
    groupKnown = true;
    service = _FakeService();
    inbox = StreamController<DecryptedMessage>.broadcast();
    notifications = ChatNotifications(
      service: service,
      onDecrypted: () => inbox.stream,
      // Like the real wiring: a known Ed key resolves to that peer's X25519
      // address, anything else (a group member we do not know yet) falls
      // through as-is, so a group never resolves to a 1:1 conversation id.
      resolvePeerPubKey: (ed) => ed == 'e' * 64 ? resolvedKey : ed,
      resolveTitle: (ed) => resolvedTitle,
      resolveGroup: (id) =>
          groupKnown && id == groupId ? (id: groupId, title: groupTitle) : null,
      isConversationVisible: (peerPubKey) => peerPubKey == visible,
      encryptedBody: 'Encrypted message',
    );
    notifications.start();
  });

  tearDown(() async {
    await notifications.stop();
    await inbox.close();
  });

  test('an inbound message becomes a banner with the resolved peers', () async {
    inbox.add(_message());
    await pumpEventQueue();

    expect(service.shown, hasLength(1));
    final shown = service.shown.single;
    expect(shown.peerPubKey, resolvedKey);
    expect(shown.title, 'Zora');
    expect(shown.body, 'hello');
  });

  test('no banner is raised for the chat that is on screen', () async {
    visible = resolvedKey;
    inbox.add(_message());
    await pumpEventQueue();

    expect(service.shown, isEmpty);
  });

  test('a banner is raised for another chat even in the foreground',
      () async {
    visible = otherKey;
    inbox.add(_message());
    await pumpEventQueue();

    expect(service.shown, hasLength(1));
    expect(service.shown.single.peerPubKey, resolvedKey);
  });

  test('a group message opens the group, not the member 1:1 chat', () async {
    visible = resolvedKey;
    inbox.add(
      _message(
        sender: groupMemberKey,
        plaintext: 'g2 $groupId $groupCorr $groupMemberKey\nв группу',
      ),
    );
    await pumpEventQueue();

    expect(service.shown, hasLength(1));
    final shown = service.shown.single;
    expect(shown.peerPubKey, groupId);
    expect(shown.title, groupTitle);
    expect(shown.body, 'в группу');
  });

  test('a group banner stays silent while the group is on screen', () async {
    visible = groupId;
    inbox.add(
      _message(
        sender: groupMemberKey,
        plaintext: 'g2 $groupId $groupCorr $groupMemberKey\nв группу',
      ),
    );
    await pumpEventQueue();

    expect(service.shown, isEmpty);
  });

  test('a container for a group this device does not know is silent',
      () async {
    groupKnown = false;
    inbox.add(
      _message(
        sender: groupMemberKey,
        plaintext: 'g2 $groupId $groupCorr $groupMemberKey\nв группу',
      ),
    );
    await pumpEventQueue();

    expect(service.shown, isEmpty);
  });

  test('multi-line plaintext is collapsed to a single-line preview',
      () async {
    inbox.add(_message(plaintext: 'line one\nline two\nthird'));
    await pumpEventQueue();

    expect(service.shown.single.body, 'line one line two third');
  });

  test('long plaintext is truncated at the preview width', () async {
    inbox.add(_message(plaintext: 'x' * 400));
    await pumpEventQueue();

    final body = service.shown.single.body;
    expect(body.length, lessThanOrEqualTo(94));
  });

  group('payload containers become the plain message text', () {
    test('a direct container shows its text, not the header', () async {
      inbox.add(_message(plaintext: 'x1 ${'a' * 64}\nПривет, мир'));
      await pumpEventQueue();

      expect(service.shown.single.body, 'Привет, мир');
    });

    test('a direct reply shows the reply text, not quote or header',
        () async {
      inbox.add(
        _message(
          plaintext: 'x2 ${'a' * 64} ${'b' * 64} ${'c' * 64}\n'
              'quoted preview\nответ',
        ),
      );
      await pumpEventQueue();

      expect(service.shown.single.body, 'ответ');
    });

    test('a group container shows the member text, not "g2 <id> <corr>"',
        () async {
      inbox.add(
        _message(
          plaintext: 'g2 $groupId $groupCorr $groupMemberKey\n'
              'сообщение в группу',
        ),
      );
      await pumpEventQueue();

      expect(service.shown.single.body, 'сообщение в группу');
    });

    test('a legacy group container shows its text', () async {
      inbox.add(_message(plaintext: 'g1$groupId\nстарое сообщение'));
      await pumpEventQueue();

      expect(service.shown.single.body, 'старое сообщение');
    });

    test('a title container is not worth a banner', () async {
      inbox.add(
        _message(
          plaintext: 't1 $groupId $groupCorr\nНовое имя группы',
        ),
      );
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('delivery and read receipts are not worth a banner', () async {
      inbox.add(_message(plaintext: 'd1\n${'a' * 64},${'b' * 64}'));
      inbox.add(_message(plaintext: 'r1\n${'a' * 64}'));
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('an undecryptable message says so instead of showing filler',
        () async {
      inbox.add(_message(plaintext: '🔒 Encrypted'));
      await pumpEventQueue();

      expect(service.shown.single.body, 'Encrypted message');
    });

    test('an undecryptable message with no placeholder is silent', () async {
      final quietInbox = StreamController<DecryptedMessage>.broadcast();
      final quiet = ChatNotifications(
        service: service,
        onDecrypted: () => quietInbox.stream,
        resolvePeerPubKey: (ed) => ed == 'e' * 64 ? resolvedKey : ed,
        resolveTitle: (ed) => resolvedTitle,
        resolveGroup: (id) => null,
        isConversationVisible: (_) => false,
      );
      quiet.start();
      quietInbox.add(_message(plaintext: '🔒 Encrypted'));
      await pumpEventQueue();
      await quiet.stop();
      await quietInbox.close();

      expect(service.shown, isEmpty);
    });

    test('a malformed container is shown as the literal text', () async {
      inbox.add(_message(plaintext: 'g2 short header\nтело'));
      await pumpEventQueue();

      expect(service.shown.single.body, 'g2 short header тело');
    });
  });

  group('media containers', () {
    String mediaDirect(String kind, String mime) =>
        'm1 ${'a' * 64} ${'b' * 64} $kind 3 1500\n$mime\nAAAA';

    test('a voice note becomes a banner naming the kind', () async {
      inbox.add(_message(plaintext: mediaDirect('voice', 'audio/mp4')));
      await pumpEventQueue();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.peerPubKey, resolvedKey);
      expect(service.shown.single.body, 'Voice message');
    });

    test('a photo becomes a banner naming the kind', () async {
      inbox.add(_message(plaintext: mediaDirect('photo', 'image/png')));
      await pumpEventQueue();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.body, 'Photo');
    });

    test('the banner body comes from the injected translation', () async {
      final translated = StreamController<DecryptedMessage>.broadcast();
      final custom = ChatNotifications(
        service: service,
        onDecrypted: () => translated.stream,
        resolvePeerPubKey: (ed) => ed == 'e' * 64 ? resolvedKey : ed,
        resolveTitle: (ed) => resolvedTitle,
        resolveGroup: (id) => null,
        isConversationVisible: (_) => false,
        mediaBody: (kind) => kind == MediaKind.voice ? 'Голосовое' : 'Фото',
      );
      custom.start();
      translated.add(_message(plaintext: mediaDirect('voice', 'audio/mp4')));
      await pumpEventQueue();
      await custom.stop();
      await translated.close();

      expect(service.shown.single.body, 'Голосовое');
    });

    test('a group media container opens the group, not a 1:1 chat',
        () async {
      visible = resolvedKey;
      inbox.add(
        _message(
          sender: groupMemberKey,
          plaintext: 'm2 $groupId $groupCorr $groupMemberKey ${'b' * 64} '
              'photo 3 0\nimage/png\nAAAA',
        ),
      );
      await pumpEventQueue();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.peerPubKey, groupId);
      expect(service.shown.single.title, groupTitle);
      expect(service.shown.single.body, 'Photo');
    });

    test('a group media container for an unknown group is silent', () async {
      groupKnown = false;
      inbox.add(
        _message(
          sender: groupMemberKey,
          plaintext: 'm2 $groupId $groupCorr $groupMemberKey ${'b' * 64} '
              'photo 3 0\nimage/png\nAAAA',
        ),
      );
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('a group media banner stays silent while the group is on screen',
        () async {
      visible = groupId;
      inbox.add(
        _message(
          sender: groupMemberKey,
          plaintext: 'm2 $groupId $groupCorr $groupMemberKey ${'b' * 64} '
              'photo 3 0\nimage/png\nAAAA',
        ),
      );
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('a malformed media container raises no banner', () async {
      inbox.add(_message(plaintext: 'm1 ${'a' * 64} ${'b' * 64} x 3 0\n'));
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });
  });

  test('a tapping the banner surfaces the peer key of the tapped chat',
      () async {
    final taps = <String>[];
    final sub = service.onNotificationTap.listen(taps.add);
    service.tap('y' * 64);
    await pumpEventQueue();
    await sub.cancel();

    expect(taps, ['y' * 64]);
  });

  test('cancelling a known chat drops the banner under the peer X key',
      () async {
    await notifications.cancel('e' * 64);

    expect(service.cancelled, [resolvedKey]);
  });

  test('cancelling an unknown or group key is passed through unchanged',
      () async {
    await notifications.cancel(otherKey);

    expect(service.cancelled, [otherKey]);
  });

  test('cancelling a read group drops the group banner by row id', () async {
    await notifications.cancel(groupId);

    expect(service.cancelled, [groupId]);
  });
}
