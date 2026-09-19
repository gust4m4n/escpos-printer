/// Plain data model of the receipt printed by this demo app.
///
/// The POS/database layer was removed; the demo builds a sample order in
/// memory via [ReceiptOrder.sample].
class ReceiptOrder {
  final String receiptNumber;
  final DateTime createdAt;
  final String orderType;
  final String? tableNumber;
  final String? queueNumber;
  final String? ordererName;
  final String cashierName;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final int serviceFee;
  final double taxPercent;
  final int roundingAdjustment;
  final int? cashPaid;
  final String? notes;

  const ReceiptOrder({
    required this.receiptNumber,
    required this.createdAt,
    required this.cashierName,
    required this.paymentMethod,
    required this.items,
    this.orderType = 'dine_in',
    this.tableNumber,
    this.queueNumber,
    this.ordererName,
    this.serviceFee = 0,
    this.taxPercent = 0,
    this.roundingAdjustment = 0,
    this.cashPaid,
    this.notes,
  });

  int get subtotal => items.fold(0, (sum, item) => sum + item.total);

  int get taxAmount => ((subtotal + serviceFee) * taxPercent / 100).round();

  int get grandTotal => subtotal + serviceFee + taxAmount + roundingAdjustment;

  int? get cashChange => cashPaid == null ? null : cashPaid! - grandTotal;

  /// Sample order used for the print/preview demo.
  static ReceiptOrder sample() => ReceiptOrder(
    receiptNumber: 'TRX-001',
    createdAt: DateTime.now(),
    cashierName: 'Admin',
    paymentMethod: 'CASH',
    orderType: 'dine_in',
    tableNumber: '5',
    ordererName: 'John',
    taxPercent: 10,
    serviceFee: 2500,
    cashPaid: 100000,
    notes: 'Please deliver the order to the back table.',
    items: const [
      ReceiptItem(
        name: 'Palm Sugar Latte',
        quantity: 2,
        price: 22000,
        variant: 'Large',
        variantPrice: 3000,
        modifiers: [ReceiptModifier(name: 'Extra Shot', price: 5000)],
      ),
      ReceiptItem(
        name: 'Chocolate Cheese Toast',
        quantity: 1,
        price: 18000,
        notes: 'No cheese please',
      ),
      ReceiptItem(name: 'Iced Sweet Tea', quantity: 3, price: 8000),
    ],
  );
}

class ReceiptItem {
  final String name;
  final int quantity;
  final int price;
  final String? variant;
  final int? variantPrice;
  final List<ReceiptModifier> modifiers;
  final String? notes;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.variant,
    this.variantPrice,
    this.modifiers = const [],
    this.notes,
  });

  int get extras =>
      (variantPrice ?? 0) +
      modifiers.fold(0, (sum, modifier) => sum + modifier.price);

  int get total => (price * quantity) + extras;
}

class ReceiptModifier {
  final String name;
  final int price;

  const ReceiptModifier({required this.name, this.price = 0});
}
