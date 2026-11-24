import 'package:flutter/material.dart';

/// The unread pill: a count, or `99+` once it stops being countable by eye.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  /// Nothing to show at zero, so callers can pass the result straight into
  /// `ListTile.trailing` without branching.
  static Widget? maybe(int count) =>
      count <= 0 ? null : UnreadBadge(count: count);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      // A min-size Row, not an aligned Container: an alignment would let the
      // box grow to the full tile width and blow up ListTile's layout.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 8),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
