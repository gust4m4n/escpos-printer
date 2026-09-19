import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/receipt_order.dart';
import '../utils/logger_x.dart';
import 'receipt_graphics.dart';
import 'receipt_text_builder.dart';
import 'settings_store.dart';

/// Renders the receipt as a JPEG image (used for the on-screen preview and for
/// sharing) and exposes the QR payload printed on the receipt.
class ReceiptRenderer {
  ReceiptRenderer._();

  static const String _defaultLogoAsset = 'assets/appicon.png';

  /// Deterministic QR payload: `{no}-{yyyyMMddHHmmss}-{amount}-{hash}`.
  static String qrData(ReceiptOrder order) {
    final d = order.createdAt;
    final dateStr =
        '${d.year}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}';
    final amount = order.grandTotal.toString();
    final digest = sha256.convert(
      utf8.encode('${order.receiptNumber}-$dateStr-$amount-Cx12Lw53'),
    );
    return '${order.receiptNumber}-$dateStr-$amount-'
        '${digest.toString().substring(0, 4)}';
  }

  /// Loads the configured logo (or the bundled default) as a decoded image.
  /// Returns null when logos are disabled.
  static Future<ui.Image?> loadLogo(ReceiptSettings settings) async {
    if (!settings.enableLogo) return null;
    try {
      if (settings.logoPath.isNotEmpty) {
        final file = File(settings.logoPath);
        if (await file.exists()) {
          return decodeImageFromList(await file.readAsBytes());
        }
      }
      final data = await rootBundle.load(_defaultLogoAsset);
      return decodeImageFromList(data.buffer.asUint8List());
    } catch (e) {
      LoggerX.log('[LOGO] Failed to load logo image: $e');
      return null;
    }
  }

  /// Renders the full receipt (header bitmap + monospace body + footer bitmap)
  /// into JPEG bytes. Returns null when rendering fails.
  static Future<Uint8List?> renderJpeg(
    ReceiptOrder order,
    ReceiptSettings receiptSettings,
    PrinterSettings printerSettings,
  ) async {
    try {
      final logo = await loadLogo(receiptSettings);
      final receipt = buildReceiptText(
        order,
        receiptSettings,
        columns: printerSettings.columns,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const textStyle = TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
      );

      // Only the body (order info + items + totals) is drawn as monospace
      // text; header and footer are bitmaps so logo/business-info and
      // footer/QR sit side by side.
      final lines = extractReceiptBody(receipt).split('\n');

      // Measure the width of one full row with the current font.
      final measurePainter = TextPainter(
        text: TextSpan(text: '-' * printerSettings.columns, style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // A uniform horizontal margin keeps header, body and footer aligned.
      const double margin = 16;
      const double topPadding = 24;
      const double lineHeight = 20;
      const double bottomPadding = 20;
      const double verticalPadding = 30;
      final double contentWidth = measurePainter.width;
      final double width = contentWidth + margin * 2;

      final headerUi = await ReceiptGraphics.renderHeader(
        logo: logo,
        businessName: receiptSettings.businessName,
        businessAddress: receiptSettings.businessAddress,
        businessContact: receiptSettings.businessContact,
        targetWidth: contentWidth,
      );
      final footerUi = await ReceiptGraphics.renderFooter(
        footerText: receiptSettings.footer,
        qrData: receiptSettings.enableQr ? qrData(order) : null,
        targetWidth: contentWidth,
      );

      final double height =
          topPadding +
          headerUi.height +
          lines.length * lineHeight +
          verticalPadding +
          footerUi.height +
          bottomPadding;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white,
      );

      canvas.drawImage(headerUi, const Offset(margin, topPadding), Paint());
      double y = topPadding + headerUi.height + 8;

      for (final line in lines) {
        TextPainter(
            text: TextSpan(text: line, style: textStyle),
            textDirection: ui.TextDirection.ltr,
          )
          ..layout()
          ..paint(canvas, Offset(margin, y));
        y += lineHeight;
      }

      canvas.drawImage(footerUi, Offset(margin, y), Paint());

      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final decoded = img.Image.fromBytes(
        width: width.toInt(),
        height: height.toInt(),
        bytes: byteData.buffer,
        numChannels: 4,
      );
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
    } catch (e, stackTrace) {
      LoggerX.log('[IMAGE] Failed to render receipt image: $e');
      LoggerX.log('[IMAGE] $stackTrace');
      return null;
    }
  }

  /// Writes [jpegBytes] to a temporary file and opens the system share sheet.
  static Future<bool> share(Uint8List jpegBytes, String receiptNumber) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'receipt_${receiptNumber}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(jpegBytes);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/jpeg')],
          text: 'Receipt $receiptNumber',
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (e) {
      LoggerX.log('[SHARE] Failed to share receipt image: $e');
      return false;
    }
  }
}
