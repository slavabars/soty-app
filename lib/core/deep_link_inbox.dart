/// Holds a `soty://` deep link that arrived while the app lock was up.
///
/// A link delivered at launch is read by the platform dispatcher before the
/// owner has unlocked the app. Acting on it immediately would add a relay host
/// or open an invited chat behind the lock, so the route is held and replayed
/// once — and only once — after a successful unlock.
class DeepLinkInbox {
  DeepLinkInbox({required this.isLocked, required this.onRoute});

  /// Whether the app lock is currently up.
  final bool Function() isLocked;

  /// Handles one accepted route.
  final Future<void> Function(String route) onRoute;

  String? _held;

  /// The route waiting for an unlock, if any. Exposed for diagnostics.
  String? get heldRoute => _held;

  /// Runs [route] now, or holds it while the app is locked.
  Future<void> submit(String route) async {
    if (isLocked()) {
      // Latest wins: a second link replaced by the user is not worth a queue,
      // and a stale host link must not be applied after a newer one.
      _held = route;
      return;
    }
    await onRoute(route);
  }

  /// Applies the held route after an unlock. A no-op when nothing is held, so
  /// it is safe to call on every unlock, and it keeps holding the route if the
  /// lock is somehow still up when it is called.
  Future<void> release() async {
    final route = _held;
    if (route == null || isLocked()) return;
    _held = null;
    await onRoute(route);
  }
}
