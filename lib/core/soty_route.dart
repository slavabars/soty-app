import 'host/host_link.dart';
import 'invite_link.dart';

/// Whether [uri] is one of the `soty://` deep links the app actually acts on:
/// `soty://invite?claim=…` with a non-empty claim and `soty://host?addr=…` with
/// a non-empty address.
///
/// This is the single source of truth shared by the message linkifier (what
/// may become tappable) and the deep-link dispatcher (what a tapped or
/// externally opened link reaches), so a message can never surface an
/// actionable route the app does not handle.
bool isSotyRoute(Uri uri) {
  if (uri.scheme != InviteLink.scheme) return false;
  if (uri.host == InviteLink.host) {
    return (uri.queryParameters['claim'] ?? '').isNotEmpty;
  }
  if (uri.host == HostLink.host) {
    return (uri.queryParameters['addr'] ?? '').isNotEmpty;
  }
  return false;
}
