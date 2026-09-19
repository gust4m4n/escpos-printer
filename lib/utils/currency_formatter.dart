import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _idrFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  static String format(num amount) => _idrFormatter.format(amount);

  /// Formats the amount without the "Rp" symbol.
  static String formatNumber(num amount) =>
      _numberFormatter.format(amount).trim();
}
