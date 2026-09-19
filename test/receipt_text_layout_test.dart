import 'package:escpos_printer/services/receipt_text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptTextLayout.centerText', () {
    test('returns text as-is when wider than width', () {
      expect(ReceiptTextLayout.centerText('abcdefgh', 4), 'abcdefgh');
    });

    test('left-pads with spaces to center within width', () {
      expect(ReceiptTextLayout.centerText('hi', 6), '  hi');
    });
  });

  group('ReceiptTextLayout.wrapText', () {
    test('returns single-element list when text fits', () {
      expect(ReceiptTextLayout.wrapText('short', 10), ['short']);
    });

    test('wraps text on word boundaries', () {
      final lines = ReceiptTextLayout.wrapText('the quick brown fox', 10);
      expect(lines.every((l) => l.length <= 10), isTrue);
      expect(lines.join(' '), 'the quick brown fox');
    });

    test('hard-splits words longer than width', () {
      final lines = ReceiptTextLayout.wrapText('superlongword', 5);
      expect(lines, ['super', 'longw', 'ord']);
    });

    test('returns at least an empty list element', () {
      expect(ReceiptTextLayout.wrapText('', 5), ['']);
    });
  });

  group('ReceiptTextLayout.labelValueRow', () {
    test('aligns value to the right of width', () {
      final row = ReceiptTextLayout.labelValueRow('Total:', '100', 32);
      expect(row.length, 32);
      expect(row.startsWith('Total:'), isTrue);
      expect(row.endsWith('100'), isTrue);
    });

    test('keeps at least one space gap when overflowing', () {
      final row = ReceiptTextLayout.labelValueRow(
        'VeryLongLabelHereForSure',
        'XYZ12345',
        20,
      );
      expect(row.contains(' '), isTrue);
    });
  });
}
