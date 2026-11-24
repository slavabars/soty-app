/// Delivery lifecycle of this device's own outgoing envelopes.
///
/// Persisted as an ordinal and only ever advanced: queued (composed but no
/// transport accepted it) → sent (handed to the network) → delivered (the
/// recipient device acknowledged) → read (the recipient opened the chat).
enum MessageStatus {
  queued,
  sent,
  delivered,
  read;

  /// Maps a stored ordinal back to a status, clamping hostile/unknown values
  /// to [queued] instead of throwing (storage is not a parse boundary).
  static MessageStatus fromOrdinal(int raw) {
    if (raw < 0 || raw >= MessageStatus.values.length) return queued;
    return MessageStatus.values[raw];
  }
}
