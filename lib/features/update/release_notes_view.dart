import 'package:flutter/material.dart';

/// Renders the small markdown subset used by release notes: headings, lists,
/// emphasis, code spans, rules and the file table.
///
/// The table is the whole reason this widget exists: the release notes carry a
/// `| file | sha256 |` block that must never reach the screen as raw pipes.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodySmall;
    final children = <Widget>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimRight();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      if (trimmed.startsWith('|')) {
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final cells = _cells(lines[i]);
          if (!_isSeparator(cells)) rows.add(cells);
          i++;
        }
        i--;
        if (rows.isNotEmpty) children.add(_table(context, rows));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        children.add(_heading(theme.textTheme.labelMedium, trimmed, 4, 8));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        children.add(_heading(theme.textTheme.labelLarge, trimmed, 3, 10));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        children.add(_heading(theme.textTheme.titleSmall, trimmed, 2, 12));
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: bodyStyle),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _inline(trimmed.substring(2).trim(), bodyStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final dot = trimmed.indexOf('.');
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trimmed.substring(0, dot + 1)} ', style: bodyStyle),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _inline(
                        trimmed.substring(dot + 1).trim(),
                        bodyStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (trimmed == '---' || trimmed == '***') {
        children.add(const Divider(height: 16));
        continue;
      }
      children.add(
        Text.rich(
          TextSpan(children: _inline(trimmed, bodyStyle)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static Widget _heading(
    TextStyle? style,
    String line,
    int markerLength,
    double top,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 2),
      child: Text(line.substring(markerLength).trim(), style: style),
    );
  }

  static List<String> _cells(String line) {
    final parts = line.trim().split('|');
    if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
    if (parts.isNotEmpty && parts.last.trim().isEmpty) parts.removeLast();
    return [for (final part in parts) part.trim()];
  }

  static bool _isSeparator(List<String> cells) {
    if (cells.isEmpty) return false;
    final rule = RegExp(r'^:?-{2,}:?$');
    return cells.every((cell) => rule.hasMatch(cell));
  }

  Widget _table(BuildContext context, List<List<String>> rows) {
    final theme = Theme.of(context);
    final columns = rows.fold<int>(
      1,
      (max, row) => row.length > max ? row.length : max,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Table(
        columnWidths: {
          for (var i = 0; i < columns; i++)
            i: i == 0 ? const FlexColumnWidth(2) : const FlexColumnWidth(3),
        },
        border: TableBorder.all(color: theme.dividerColor, width: 0.5),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                    )
                  : null,
              children: [
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: _cell(
                      theme,
                      c < rows[r].length ? rows[r][c] : '',
                      header: r == 0,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(ThemeData theme, String value, {required bool header}) {
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: header ? FontWeight.w600 : FontWeight.w400,
      fontFamily: RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)
          ? 'monospace'
          : null,
      fontSize: RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value) ? 10 : null,
    );
    if (header || value.length < 24) {
      return Text(value, style: style);
    }
    return SelectableText(value, style: style);
  }

  List<InlineSpan> _inline(String s, TextStyle? style) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|\*(.+?)\*');
    var last = 0;
    for (final match in regex.allMatches(s)) {
      if (match.start > last) {
        spans.add(TextSpan(text: s.substring(last, match.start), style: style));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: style?.copyWith(fontFamily: 'monospace'),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      last = match.end;
    }
    if (last < s.length) {
      spans.add(TextSpan(text: s.substring(last), style: style));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: s, style: style));
    }
    return spans;
  }
}
