import 'package:intl/intl.dart';

import '../models/receipt_order.dart';
import '../utils/currency_formatter.dart';
import 'receipt_text_layout.dart';
import 'settings_store.dart';

/// Builds the plain-text receipt sent to thermal printers.
///
/// The layout adapts to the paper width via [columns]: 58mm paper uses 32
/// columns (the default) while 80mm paper uses 48 columns.
String buildReceiptText(
  ReceiptOrder order,
  ReceiptSettings settings, {
  int columns = 32,
}) {
  final buffer = StringBuffer();
  final dateFormat = DateFormat('MM/dd/yyyy HH:mm');

  // Paper-width derived layout metrics.
  // - [width]      : total columns available (32 for 58mm, 48 for 80mm)
  // - [priceCol]   : fixed width reserved for right-aligned prices
  // - [itemNameCol]: product name column width on lines that carry a price
  // - [modNameCol] : variant/modifier name width on lines with "+ " + price
  // - [wrapCol]    : wrap width for variant/modifier lines without a price
  final width = columns;
  const priceCol = 10;
  final itemNameCol = width - priceCol - 1;
  final modNameCol = width - priceCol - 3;
  final wrapCol = width - 2;
  final divider = '-' * width;

  String center(String text) => ReceiptTextLayout.centerText(text, width);
  List<String> wrap(String text, int max) =>
      ReceiptTextLayout.wrapText(text, max);
  void row(String label, String value) =>
      buffer.writeln(ReceiptTextLayout.labelValueRow(label, value, width));

  void writeCenteredMultiline(String text) {
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) {
        buffer.writeln('');
        continue;
      }
      for (final wrapped in wrap(line, width)) {
        buffer.writeln(center(wrapped));
      }
    }
  }

  /// Writes "name  price" where the name wraps onto continuation lines.
  void writePricedRow(String name, int nameWidth, String price, String prefix) {
    final lines = wrap(name, nameWidth);
    buffer.writeln(
      '$prefix${lines.first.padRight(nameWidth)} ${price.padLeft(priceCol)}',
    );
    for (var i = 1; i < lines.length; i++) {
      buffer.writeln('${' ' * prefix.length}${lines[i]}');
    }
  }

  // --- Header: business info (rendered as a bitmap when printing) ---
  final headerParts = [
    settings.businessName,
    settings.businessAddress,
    settings.businessContact,
  ].where((part) => part.trim().isNotEmpty);
  writeCenteredMultiline(headerParts.join('\n'));
  buffer.writeln(divider);

  // --- Order info ---
  row('No:', order.receiptNumber);
  row('Date:', dateFormat.format(order.createdAt.toLocal()));
  row('Type:', order.orderType == 'take_away' ? 'Take Away' : 'Dine In');

  if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
    row('Table:', order.tableNumber!);
  }
  if (order.queueNumber != null && order.queueNumber!.isNotEmpty) {
    row('Queue:', order.queueNumber!);
  }
  if (order.ordererName != null && order.ordererName!.isNotEmpty) {
    row('Customer:', order.ordererName!);
  }
  row('Cashier:', order.cashierName.toUpperCase());
  buffer.writeln(divider);

  // --- Items ---
  buffer.writeln('${'ITEM'.padRight(width - 'PRICE'.length)}PRICE');
  buffer.writeln(divider);

  for (final item in order.items) {
    final lineTotal = item.price * item.quantity;
    writePricedRow(
      item.name,
      itemNameCol,
      CurrencyFormatter.formatNumber(lineTotal),
      '',
    );

    if (item.variant != null && item.variant!.isNotEmpty) {
      final variantName = item.variant!;
      final variantPrice = item.variantPrice ?? 0;
      if (variantPrice != 0) {
        writePricedRow(
          variantName,
          modNameCol,
          CurrencyFormatter.formatNumber(variantPrice),
          '+ ',
        );
      } else {
        final lines = wrap(variantName, wrapCol);
        buffer.writeln('+ ${lines.first}');
        for (var i = 1; i < lines.length; i++) {
          buffer.writeln('  ${lines[i]}');
        }
      }
    }

    for (final modifier in item.modifiers) {
      final name = modifier.name;
      if (modifier.price != 0) {
        writePricedRow(
          name,
          modNameCol,
          CurrencyFormatter.formatNumber(modifier.price),
          '+ ',
        );
      } else {
        final lines = wrap(name, wrapCol);
        buffer.writeln('+ ${lines.first}');
        for (var i = 1; i < lines.length; i++) {
          buffer.writeln('  ${lines[i]}');
        }
      }
    }

    if (item.quantity > 1) {
      buffer.writeln(
        'x${item.quantity} @Rp. ${CurrencyFormatter.formatNumber(item.price)}',
      );
    }

    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      for (final line in wrap('Notes: ${item.notes!.trim()}', wrapCol)) {
        buffer.writeln(line);
      }
    }
  }

  buffer.writeln(divider);

  // --- Payment + totals ---
  final paymentMethod = order.paymentMethod
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
      .toUpperCase();
  row('Method:', paymentMethod);
  row('Subtotal:', CurrencyFormatter.formatNumber(order.subtotal));

  if (order.serviceFee > 0) {
    row('Service Fee:', CurrencyFormatter.formatNumber(order.serviceFee));
  }
  if (order.taxAmount > 0) {
    row(
      'Tax (${order.taxPercent.toStringAsFixed(0)}%):',
      CurrencyFormatter.formatNumber(order.taxAmount),
    );
  }
  if (order.roundingAdjustment != 0) {
    final sign = order.roundingAdjustment > 0 ? '+' : '-';
    row(
      'Rounding:',
      '$sign${CurrencyFormatter.formatNumber(order.roundingAdjustment.abs())}',
    );
  }
  row('GRAND TOTAL:', CurrencyFormatter.format(order.grandTotal));

  if (paymentMethod == 'CASH' && order.cashPaid != null) {
    row('Cash:', CurrencyFormatter.format(order.cashPaid!));
    final change = order.cashChange;
    if (change != null && change > 0) {
      row('Change:', CurrencyFormatter.format(change));
    }
  }

  if (order.notes != null && order.notes!.trim().isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('Notes:');
    for (final line in wrap(order.notes!, width)) {
      buffer.writeln(line);
    }
  }

  // Blank line required for thermal printer paper advance before cut.
  buffer.writeln('');
  buffer.writeln(divider);

  // --- Footer (rendered as a bitmap when printing) ---
  writeCenteredMultiline(settings.footer);

  return buffer.toString();
}

/// Extracts the middle section of the plain-text receipt (from the first
/// divider line to the last divider line, inclusive). The business-info header
/// and the footer text are excluded because they are rendered as side-by-side
/// bitmaps by `ReceiptGraphics`. Blank lines are stripped to save paper.
String extractReceiptBody(String receipt) {
  final lines = receipt.split('\n');
  bool isDivider(String l) =>
      l.isNotEmpty && l.length >= 5 && l.replaceAll('-', '').isEmpty;
  final first = lines.indexWhere(isDivider);
  final last = lines.lastIndexWhere(isDivider);
  if (first == -1 || last == -1 || last < first) return receipt;
  return lines
      .sublist(first, last + 1)
      .where((l) => l.trim().isNotEmpty)
      .join('\n');
}
