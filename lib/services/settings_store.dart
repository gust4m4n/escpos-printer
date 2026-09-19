import 'package:shared_preferences/shared_preferences.dart';

/// Bluetooth printer configuration ("Printer Settings").
class PrinterSettings {
  final String paperSize;
  final String address;
  final String name;

  const PrinterSettings({
    this.paperSize = '58',
    this.address = '',
    this.name = '',
  });

  /// Monospace columns available for the configured paper width.
  int get columns => paperSize == '80' ? 48 : 32;

  /// Printable width in dots (58mm ~360, 80mm ~560).
  double get dotWidth => paperSize == '80' ? 560 : 360;

  PrinterSettings copyWith({
    String? paperSize,
    String? address,
    String? name,
  }) => PrinterSettings(
    paperSize: paperSize ?? this.paperSize,
    address: address ?? this.address,
    name: name ?? this.name,
  );
}

/// Receipt content configuration ("Receipt Settings").
class ReceiptSettings {
  final String businessName;
  final String businessAddress;
  final String businessContact;
  final String footer;
  final bool enableLogo;
  final bool enableQr;
  final String logoPath;

  const ReceiptSettings({
    this.businessName = 'THE CORNER DINER',
    this.businessAddress = '35 Sample Street',
    this.businessContact = '0700-12345678',
    this.footer = 'Thank You\nSee You Again Soon\n@escposprinter',
    this.enableLogo = true,
    this.enableQr = true,
    this.logoPath = '',
  });

  ReceiptSettings copyWith({
    String? businessName,
    String? businessAddress,
    String? businessContact,
    String? footer,
    bool? enableLogo,
    bool? enableQr,
    String? logoPath,
  }) => ReceiptSettings(
    businessName: businessName ?? this.businessName,
    businessAddress: businessAddress ?? this.businessAddress,
    businessContact: businessContact ?? this.businessContact,
    footer: footer ?? this.footer,
    enableLogo: enableLogo ?? this.enableLogo,
    enableQr: enableQr ?? this.enableQr,
    logoPath: logoPath ?? this.logoPath,
  );
}

/// Persists printer and receipt settings in [SharedPreferences].
class SettingsStore {
  SettingsStore._();

  static const _kPaperSize = 'printer_paper_size';
  static const _kAddress = 'printer_address';
  static const _kName = 'printer_name';
  static const _kBusinessName = 'business_name';
  static const _kBusinessAddress = 'business_address';
  static const _kBusinessContact = 'business_contact';
  static const _kFooter = 'receipt_footer';
  static const _kEnableLogo = 'printer_enable_logo';
  static const _kEnableQr = 'printer_enable_qr';
  static const _kLogoPath = 'business_logo_path';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<PrinterSettings> loadPrinter() async {
    final prefs = await _instance();
    const defaults = PrinterSettings();
    return PrinterSettings(
      paperSize: prefs.getString(_kPaperSize) == '80' ? '80' : '58',
      address: prefs.getString(_kAddress) ?? defaults.address,
      name: prefs.getString(_kName) ?? defaults.name,
    );
  }

  static Future<void> savePrinter(PrinterSettings settings) async {
    final prefs = await _instance();
    await prefs.setString(_kPaperSize, settings.paperSize);
    await prefs.setString(_kAddress, settings.address);
    await prefs.setString(_kName, settings.name);
  }

  static Future<ReceiptSettings> loadReceipt() async {
    final prefs = await _instance();
    const defaults = ReceiptSettings();
    return ReceiptSettings(
      businessName: prefs.getString(_kBusinessName) ?? defaults.businessName,
      businessAddress:
          prefs.getString(_kBusinessAddress) ?? defaults.businessAddress,
      businessContact:
          prefs.getString(_kBusinessContact) ?? defaults.businessContact,
      footer: prefs.getString(_kFooter) ?? defaults.footer,
      enableLogo: prefs.getBool(_kEnableLogo) ?? defaults.enableLogo,
      enableQr: prefs.getBool(_kEnableQr) ?? defaults.enableQr,
      logoPath: prefs.getString(_kLogoPath) ?? defaults.logoPath,
    );
  }

  static Future<void> saveReceipt(ReceiptSettings settings) async {
    final prefs = await _instance();
    await prefs.setString(_kBusinessName, settings.businessName);
    await prefs.setString(_kBusinessAddress, settings.businessAddress);
    await prefs.setString(_kBusinessContact, settings.businessContact);
    await prefs.setString(_kFooter, settings.footer);
    await prefs.setBool(_kEnableLogo, settings.enableLogo);
    await prefs.setBool(_kEnableQr, settings.enableQr);
    await prefs.setString(_kLogoPath, settings.logoPath);
  }
}
