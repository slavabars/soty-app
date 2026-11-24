import 'package:flutter/widgets.dart';

import '../../core/i18n/soty_l10n.dart';
import '../../models/peer.dart';

/// How recently a peer was seen, as the UI shows it.
enum PeerPresence {
  /// A live transport reports the peer right now.
  online,

  /// No live transport, but the peer was seen within [peerRecentWindow] —
  /// the fallback that keeps a just-disconnected peer from looking cold.
  recent,

  /// Nothing heard for longer than [peerRecentWindow].
  offline,
}

/// How long after the last contact a peer still counts as recently active.
const Duration peerRecentWindow = Duration(minutes: 5);

/// Presence of [peer] at [now]. A peer we have never heard from is offline,
/// and a clock that went backwards counts as "seen just now" rather than as
/// an absurd age.
PeerPresence presenceOf(DtmPeer? peer, {DateTime? now}) {
  if (peer == null) return PeerPresence.offline;
  if (peer.online) return PeerPresence.online;
  return _age(peer, now) <= peerRecentWindow
      ? PeerPresence.recent
      : PeerPresence.offline;
}

/// Human label for [peer]: "online" while a transport reports it live, the
/// last-seen time otherwise. A peer we know nothing about is "offline".
String presenceLabel(BuildContext context, DtmPeer? peer) {
  if (peer == null) return SotyL10n.tr(context, 'offline');
  if (peer.online) return SotyL10n.tr(context, 'online');
  return lastSeenLabel(context, peer);
}

/// Relative "last seen" label in the largest sensible unit.
String lastSeenLabel(BuildContext context, DtmPeer peer, {DateTime? now}) {
  final age = _age(peer, now);
  if (age.inMinutes < 60) {
    return age.inMinutes == 0
        ? SotyL10n.tr(context, 'last seen just now')
        : SotyL10n.tr(context, 'last seen {n} min ago', {'n': age.inMinutes});
  }
  if (age.inHours < 24) {
    return SotyL10n.tr(context, 'last seen {n} h ago', {'n': age.inHours});
  }
  return SotyL10n.tr(context, 'last seen {n} d ago', {'n': age.inDays});
}

Duration _age(DtmPeer peer, DateTime? now) {
  final age = (now ?? DateTime.now()).difference(peer.lastSeen);
  return age.isNegative ? Duration.zero : age;
}
