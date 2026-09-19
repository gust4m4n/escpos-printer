/// Pure text-layout helpers for fixed-width receipt printing (58mm = 32 cols).
class ReceiptTextLayout {
  ReceiptTextLayout._();

  /// Centers [text] within [width]. If text is wider than [width] it is
  /// returned as-is.
  static String centerText(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return '${' ' * padding}$text';
  }

  /// Word-wraps [text] to fit within [width]. Words longer than [width] are
  /// hard-split. Always returns a non-empty list (at least `['']`).
  static List<String> wrapText(String text, int width) {
    if (text.length <= width) return [text];

    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (word.length > width) {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine.trim());
          currentLine = '';
        }
        for (var i = 0; i < word.length; i += width) {
          final end = (i + width < word.length) ? i + width : word.length;
          lines.add(word.substring(i, end));
        }
      } else {
        final testLine = currentLine.isEmpty ? word : '$currentLine $word';
        if (testLine.length <= width) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine.trim());
          }
          currentLine = word;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.trim());
    }

    return lines.isEmpty ? [''] : lines;
  }

  /// Right-aligns [value] against [label] within [width] with at least one
  /// space gap. Returns the formatted line (no trailing newline).
  static String labelValueRow(String label, String value, int width) {
    final padding = width - label.length - value.length;
    return '$label${''.padLeft(padding < 1 ? 1 : padding)}$value';
  }
}
