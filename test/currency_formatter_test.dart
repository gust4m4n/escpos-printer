import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:escpos_printer/utils/currency_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('CurrencyFormatter', () {
    test('format prepends Rp and groups thousands', () {
      final formatted = CurrencyFormatter.format(1234567);
      expect(formatted, startsWith('Rp '));
      expect(formatted, contains('1.234.567'));
    });

    test('format handles zero', () {
      expect(CurrencyFormatter.format(0), 'Rp 0');
    });

    test('format truncates decimals', () {
      expect(CurrencyFormatter.format(1500.75), 'Rp 1.501');
    });

    test('formatNumber omits the currency symbol', () {
      final formatted = CurrencyFormatter.formatNumber(50000);
      expect(formatted, isNot(contains('Rp')));
      expect(formatted, '50.000');
    });

    test('formatNumber trims whitespace', () {
      expect(CurrencyFormatter.formatNumber(0), '0');
    });
  });
}
