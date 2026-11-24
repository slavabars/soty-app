import 'package:dtm_app/core/deep_link_inbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a route is applied immediately when the app is unlocked', () async {
    const locked = false;
    final applied = <String>[];
    final inbox = DeepLinkInbox(
      isLocked: () => locked,
      onRoute: (route) async => applied.add(route),
    );

    await inbox.submit('soty://host?addr=wss%3A%2F%2Frelay.example%2Fws');

    expect(applied, hasLength(1));
    expect(inbox.heldRoute, isNull);
  });

  test('a host link delivered behind the lock is not applied', () async {
    const locked = true;
    final applied = <String>[];
    final inbox = DeepLinkInbox(
      isLocked: () => locked,
      onRoute: (route) async => applied.add(route),
    );

    await inbox.submit('soty://host?addr=wss%3A%2F%2Frelay.example%2Fws');

    expect(
      applied,
      isEmpty,
      reason: 'a link must not add a host behind the app lock',
    );
    expect(inbox.heldRoute, isNotNull);
  });

  test('the held route runs exactly once after the unlock', () async {
    var locked = true;
    final applied = <String>[];
    final inbox = DeepLinkInbox(
      isLocked: () => locked,
      onRoute: (route) async => applied.add(route),
    );
    const route = 'soty://invite?claim=abc';
    await inbox.submit(route);
    await inbox.release();
    expect(applied, isEmpty, reason: 'still locked');

    locked = false;
    await inbox.release();
    expect(applied, [route]);
    expect(inbox.heldRoute, isNull);

    // A second unlock (the app locks again later) replays nothing.
    await inbox.release();
    expect(applied, [route]);
  });

  test('only the latest held route survives', () async {
    var locked = true;
    final applied = <String>[];
    final inbox = DeepLinkInbox(
      isLocked: () => locked,
      onRoute: (route) async => applied.add(route),
    );
    await inbox.submit('soty://host?addr=ws%3A%2F%2Fone');
    await inbox.submit('soty://host?addr=ws%3A%2F%2Ftwo');
    await inbox.release();
    expect(applied, isEmpty, reason: 'a release while locked keeps holding');

    locked = false;
    await inbox.release();
    expect(applied, ['soty://host?addr=ws%3A%2F%2Ftwo']);
  });
}
