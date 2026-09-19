import 'dart:convert';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc_pos;
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_order.dart';
import '../utils/logger_x.dart';
import 'receipt_graphics.dart';
import 'receipt_renderer.dart';
import 'receipt_text_builder.dart';
import 'settings_store.dart';

/// Sends ESC/POS data to the configured Bluetooth thermal printer.
class PrinterService {
  PrinterService._();

  /// Strips the optional `BT:` prefix used by some saved addresses.
  static String _cleanAddress(String address) =>
      address.startsWith('BT:') ? address.substring(3) : address;

  /// Prints [order] as a receipt: header bitmap, monospace body, footer bitmap
  /// with the validation QR, then a paper feed and partial cut.
  ///
  /// Each section is sent as its own transmission so the printer can finish
  /// rasterizing a bitmap before the next chunk (especially the cut) arrives.
  static Future<bool> printReceipt(
    ReceiptOrder order,
    ReceiptSettings receiptSettings,
    PrinterSettings printerSettings,
  ) async {
    if (printerSettings.address.isEmpty) {
      LoggerX.log('[PRINTER] Printer address is empty');
      return false;
    }

    try {
      final address = _cleanAddress(printerSettings.address);
      final is80mm = printerSettings.paperSize == '80';
      final targetWidth = printerSettings.dotWidth;

      final receipt = buildReceiptText(
        order,
        receiptSettings,
        columns: printerSettings.columns,
      );

      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(
        is80mm ? esc_pos.PaperSize.mm80 : esc_pos.PaperSize.mm58,
        profile,
      );

      final headerImg = await _rasterize(
        ReceiptGraphics.renderHeader(
          logo: await ReceiptRenderer.loadLogo(receiptSettings),
          businessName: receiptSettings.businessName,
          businessAddress: receiptSettings.businessAddress,
          businessContact: receiptSettings.businessContact,
          targetWidth: targetWidth,
        ),
      );
      final footerImg = await _rasterize(
        ReceiptGraphics.renderFooter(
          footerText: receiptSettings.footer,
          qrData: receiptSettings.enableQr
              ? ReceiptRenderer.qrData(order)
              : null,
          targetWidth: targetWidth,
        ),
      );

      // Transmission 1: init + header bitmap.
      final header = <int>[0x1B, 0x40];
      if (headerImg != null) {
        header.addAll(
          generator.image(headerImg, align: esc_pos.PosAlign.center),
        );
      }
      header.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - left align
      await _send(address, header, keepConnected: true, timeoutSeconds: 20);
      await Future.delayed(const Duration(milliseconds: 1200));

      // Transmission 2: body text. No ESC @ here, it would discard the header.
      final body = <int>[
        0x1B,
        0x61,
        0x00,
        ...utf8.encode(extractReceiptBody(receipt)),
        ...utf8.encode('\n'),
      ];
      await _send(address, body, keepConnected: true, timeoutSeconds: 30);
      await Future.delayed(const Duration(milliseconds: 300));

      // Transmission 3: footer bitmap, sent alone so the cut cannot arrive
      // while the QR is still being rasterized.
      if (footerImg != null) {
        final footer = <int>[
          ...generator.image(footerImg, align: esc_pos.PosAlign.center),
          0x1B,
          0x61,
          0x00,
        ];
        await _send(address, footer, keepConnected: true, timeoutSeconds: 20);
        await Future.delayed(const Duration(milliseconds: 1200));
      }

      // Transmission 4: feed the footer past the cutter, then cut.
      await _send(
        address,
        [0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x41, 0x03],
        keepConnected: false,
        timeoutSeconds: 20,
      );

      LoggerX.log('[PRINTER] Receipt printed successfully');
      return true;
    } catch (e) {
      LoggerX.log('[PRINTER] Error while printing: $e');
      return false;
    }
  }

  static Future<img.Image?> _rasterize(Future<ui.Image> render) async {
    try {
      final converted = await ReceiptGraphics.toImgImage(await render);
      return converted == null ? null : img.grayscale(converted);
    } catch (e) {
      LoggerX.log('[PRINTER] Failed to render bitmap: $e');
      return null;
    }
  }

  static Future<void> _send(
    String address,
    List<int> data, {
    required bool keepConnected,
    required int timeoutSeconds,
  }) {
    LoggerX.log('[PRINTER] Sending ${data.length} bytes...');
    return FlutterBluetoothPrinter.printBytes(
      address: address,
      data: Uint8List.fromList(data),
      keepConnected: keepConnected,
    ).timeout(Duration(seconds: timeoutSeconds));
  }
}
