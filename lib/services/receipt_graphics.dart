import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

/// Renders the two-column receipt header and footer as bitmaps so that the
/// exact same side-by-side layout can be used for both the preview/share image
/// and the thermal printer (which cannot lay out a bitmap next to text using
/// plain ESC/POS commands).
///
/// Header layout:  [ logo (square, top-left) ] [ business name / address /
/// contact ]
/// Footer layout:  [ footer text ] [ QR validation (square, bottom-right) ]
class ReceiptGraphics {
  ReceiptGraphics._();

  /// Fraction of the paper width used for the logo box.
  static const double boxFraction = 0.30;

  /// Fraction of the paper width used for the QR box. Larger than the logo so
  /// the QR stays easy to scan.
  static const double qrFraction = 0.40;

  /// Renders the header: logo fitted inside a square box on the top-left and
  /// the business name/address/contact stacked to its right.
  ///
  /// When [logo] is null the business info is centered across the full width.
  static Future<ui.Image> renderHeader({
    ui.Image? logo,
    required String businessName,
    required String businessAddress,
    required String businessContact,
    required double targetWidth,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // No left/right margin so the header content aligns flush with the
    // receipt's content text. No top/bottom margin either, to save paper.
    const double vPad = 0;
    const double hPad = 0;
    const double gap = 12;
    final bool hasLogo = logo != null;
    final double logoBox = hasLogo ? targetWidth * boxFraction : 0;

    final double textLeft = hasLogo ? hPad + logoBox + gap : hPad;
    final double textWidth = targetWidth - textLeft - hPad;
    final TextAlign align = hasLogo ? TextAlign.left : TextAlign.center;

    const nameStyle = TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );
    const infoStyle = TextStyle(color: Colors.black, fontSize: 16);

    // Strip blank lines from each field to save paper.
    String clean(String s) =>
        s.split('\n').where((l) => l.trim().isNotEmpty).join('\n');
    final name = clean(businessName);
    final address = clean(businessAddress);
    final contact = clean(businessContact);

    final painters = <TextPainter>[];
    if (name.isNotEmpty) {
      painters.add(_layout(name, nameStyle, textWidth, align: align));
    }
    if (address.isNotEmpty) {
      painters.add(_layout(address, infoStyle, textWidth, align: align));
    }
    if (contact.isNotEmpty) {
      painters.add(_layout(contact, infoStyle, textWidth, align: align));
    }

    double textBlockHeight = 0;
    for (final p in painters) {
      textBlockHeight += p.height + 3;
    }

    // Scale the logo to fit inside the square box, preserving aspect ratio.
    double logoW = 0;
    double logoH = 0;
    if (hasLogo) {
      final ar = logo.width / logo.height;
      if (ar >= 1) {
        logoW = logoBox;
        logoH = logoBox / ar;
      } else {
        logoH = logoBox;
        logoW = logoBox * ar;
      }
    }

    final double contentHeight = math.max(logoBox, textBlockHeight);
    final double height = contentHeight + vPad * 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, targetWidth, height),
      Paint()..color = Colors.white,
    );

    if (hasLogo) {
      final lx = hPad + (logoBox - logoW) / 2;
      final ly = vPad + (contentHeight - logoH) / 2;
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(lx, ly, logoW, logoH),
        Paint(),
      );
    }

    double ty = vPad + (contentHeight - textBlockHeight) / 2;
    for (final p in painters) {
      p.paint(canvas, Offset(textLeft, ty));
      ty += p.height + 3;
    }

    final picture = recorder.endRecording();
    return picture.toImage(targetWidth.toInt(), height.ceil());
  }

  /// Renders the footer: footer text on the left and the QR validation code
  /// fitted inside a square box on the bottom-right.
  ///
  /// When [qrData] is null/empty the footer text is centered across the full
  /// width and no QR is drawn.
  static Future<ui.Image> renderFooter({
    required String footerText,
    String? qrData,
    required double targetWidth,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // No left/right margin so the footer content aligns flush with the
    // receipt's content text. No top/bottom margin either, to save paper.
    const double vPad = 0;
    const double hPad = 0;
    const double gap = 12;
    final bool hasQr = qrData != null && qrData.isNotEmpty;
    final double qrBox = hasQr ? targetWidth * qrFraction : 0;

    final double textWidth = targetWidth - hPad * 2 - (hasQr ? qrBox + gap : 0);

    // Strip blank lines to save paper.
    final cleanFooter = footerText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .join('\n');

    const footerStyle = TextStyle(color: Colors.black, fontSize: 16);
    final textPainter = _layout(
      cleanFooter,
      footerStyle,
      textWidth < 1 ? 1 : textWidth,
      align: TextAlign.center,
    );

    final double contentHeight = math.max(qrBox, textPainter.height);
    final double height = contentHeight + vPad * 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, targetWidth, height),
      Paint()..color = Colors.white,
    );

    textPainter.paint(
      canvas,
      Offset(hPad, vPad + (contentHeight - textPainter.height) / 2),
    );

    if (hasQr) {
      final qrX = targetWidth - hPad - qrBox;
      final qrY = vPad + (contentHeight - qrBox) / 2;
      _drawQr(canvas, qrData, qrX, qrY, qrBox);
    }

    final picture = recorder.endRecording();
    return picture.toImage(targetWidth.toInt(), height.ceil());
  }

  /// Converts a [ui.Image] (rendered on a canvas) into an [img.Image] suitable
  /// for the `image` package / ESC-POS raster printing.
  static Future<img.Image?> toImgImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: byteData.buffer,
      numChannels: 4,
    );
  }

  static TextPainter _layout(
    String text,
    TextStyle style,
    double maxWidth, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
    );
    tp.layout(maxWidth: maxWidth);
    return tp;
  }

  static void _drawQr(
    Canvas canvas,
    String data,
    double x,
    double y,
    double size,
  ) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final pixelSize = size / qrImage.moduleCount;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int c = 0; c < qrImage.moduleCount; c++) {
      for (int r = 0; r < qrImage.moduleCount; r++) {
        if (qrImage.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + (c * pixelSize),
              y + (r * pixelSize),
              pixelSize + 0.5,
              pixelSize + 0.5,
            ),
            paint,
          );
        }
      }
    }
  }
}
