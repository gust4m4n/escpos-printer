import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/receipt_order.dart';
import '../services/printer_service.dart';
import '../services/receipt_renderer.dart';
import '../services/settings_store.dart';

/// Bottom sheet that previews the rendered receipt image and lets the user
/// print it to the Bluetooth printer or share it as an image.
class ReceiptPreviewSheet extends StatefulWidget {
  final ReceiptOrder order;
  final ReceiptSettings receiptSettings;
  final PrinterSettings printerSettings;

  const ReceiptPreviewSheet({
    super.key,
    required this.order,
    required this.receiptSettings,
    required this.printerSettings,
  });

  static Future<void> show(
    BuildContext context, {
    required ReceiptOrder order,
    required ReceiptSettings receiptSettings,
    required PrinterSettings printerSettings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReceiptPreviewSheet(
        order: order,
        receiptSettings: receiptSettings,
        printerSettings: printerSettings,
      ),
    );
  }

  @override
  State<ReceiptPreviewSheet> createState() => _ReceiptPreviewSheetState();
}

class _ReceiptPreviewSheetState extends State<ReceiptPreviewSheet> {
  Uint8List? _image;
  bool _isRendering = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final bytes = await ReceiptRenderer.renderJpeg(
      widget.order,
      widget.receiptSettings,
      widget.printerSettings,
    );
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _isRendering = false;
    });
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _print() async {
    if (widget.printerSettings.address.isEmpty) {
      _notify('Select a Bluetooth printer first.', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    final success = await PrinterService.printReceipt(
      widget.order,
      widget.receiptSettings,
      widget.printerSettings,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      Navigator.of(context).pop();
      _notify('Receipt sent to the printer.');
    } else {
      _notify('Print failed. Check the printer connection.', isError: true);
    }
  }

  Future<void> _share() async {
    final bytes = _image;
    if (bytes == null) return;

    setState(() => _isBusy = true);
    await ReceiptRenderer.share(bytes, widget.order.receiptNumber);
    if (!mounted) return;
    setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 12),
                  Text(
                    'Receipt Preview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: _buildPreview(theme)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBusy || _image == null ? null : _print,
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy || _image == null ? null : _share,
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    if (_isRendering) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_image == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Text('Failed to build the receipt preview.'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(_image!, fit: BoxFit.fitWidth),
      ),
    );
  }
}
