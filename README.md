# ESCPOS Printer

A Flutter (Android) app for printing receipts to Bluetooth thermal printers using ESC/POS commands. The app works as a demo/starter: order data is created in memory (`ReceiptOrder.sample()`), with no database or POS backend.

## Features

- **Scan & select Bluetooth printer** — discovers nearby devices, including location/Bluetooth permission checks and adapter status.
- **58 mm & 80 mm paper support** — column width (32/48) and dot width (360/560) adjust automatically.
- **Receipt settings** — business name, address, contact, footer text, custom logo (picked from the gallery), plus toggles for the logo and QR code.
- **Receipt preview** — the receipt is rendered to a JPEG image and shown in a bottom sheet before printing.
- **ESC/POS printing** — header (logo bitmap + business identity), monospace text body, footer (text + QR), then feed and partial cut. Each section is sent separately so the printer has time to rasterize the bitmap.
- **Share receipt** — export the rendered result as an image through the system share sheet.
- **Validation QR** — deterministic payload `{noStruk}-{yyyyMMddHHmmss}-{total}-{hash}` using a truncated SHA-256 digest.
- **Settings persistence** — all printer and receipt configuration is stored in `SharedPreferences`.

## Project Structure

```
lib/
  main.dart                      # Entry point, MaterialApp + theme
  models/receipt_order.dart      # Order, item, and modifier models, total calculation
  services/
    printer_service.dart         # Sends ESC/POS data to the Bluetooth printer
    receipt_renderer.dart        # Renders the receipt to JPEG, QR payload, sharing
    receipt_graphics.dart        # Draws header & footer (logo, QR)
    receipt_text_builder.dart    # Builds the receipt text
    receipt_text_layout.dart     # Monospace column layout utilities
    settings_store.dart          # PrinterSettings & ReceiptSettings + persistence
  theme/app_theme.dart           # Light/dark theme
  utils/                         # Currency formatting, logger
  views/
    home_page.dart               # Printer & receipt settings page
    receipt_preview_sheet.dart   # Preview, print and share buttons
test/                            # Unit tests for text layout & currency formatting
```

## Main Packages

`flutter_bluetooth_printer`, `esc_pos_utils_plus`, `flutter_blue_plus`, `permission_handler`, `image`, `image_picker`, `qr`, `shared_preferences`, `path_provider`, `share_plus`, `intl`, `crypto`.

## Running

```bash
flutter pub get
flutter run
```

Regenerate icons and splash screen:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Run tests:

```bash
flutter test
```

## Usage

1. Turn on Bluetooth and grant the permissions requested by the app.
2. Tap the scan button, then select your thermal printer from the device list.
3. Choose the paper size (58 mm or 80 mm).
4. Fill in the business details, footer, and logo in the receipt settings section.
5. Tap **Preview Receipt**, then print or share the result.

## Notes

- The primary target is Android (minimum SDK 21). Splash/icon configuration is enabled for Android only.
- Order data in the demo is static; replace `ReceiptOrder.sample()` with real data to integrate with a POS system.
