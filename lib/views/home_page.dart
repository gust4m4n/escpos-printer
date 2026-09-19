import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/receipt_order.dart';
import '../services/settings_store.dart';
import '../utils/logger_x.dart';
import 'receipt_preview_sheet.dart';

/// The single page of the demo: "Printer Settings" and "Receipt Settings"
/// combined, plus the action that opens the receipt preview.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _scanDuration = Duration(seconds: 3);

  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessContactController = TextEditingController();
  final _footerController = TextEditingController();

  PrinterSettings _printer = const PrinterSettings();
  ReceiptSettings _receipt = const ReceiptSettings();

  bool _isLoading = true;
  bool _isScanning = false;
  bool _isBluetoothOn = true;
  String? _scanMessage;

  List<BluetoothDevice> _devices = [];
  // The package does not export the `DiscoveryState` type of this stream.
  StreamSubscription<Object?>? _discoverySubscription;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterSubscription;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _listenToBluetoothState();
    _load();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _adapterSubscription?.cancel();
    _scanTimer?.cancel();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessContactController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final printer = await SettingsStore.loadPrinter();
    final receipt = await SettingsStore.loadReceipt();
    if (!mounted) return;

    _businessNameController.text = receipt.businessName;
    _businessAddressController.text = receipt.businessAddress;
    _businessContactController.text = receipt.businessContact;
    _footerController.text = receipt.footer;

    setState(() {
      _printer = printer;
      _receipt = receipt;
      _isLoading = false;
    });

    _startScan();
  }

  // --- Settings persistence -------------------------------------------------

  Future<void> _updatePrinter(PrinterSettings next) async {
    setState(() => _printer = next);
    await SettingsStore.savePrinter(next);
  }

  Future<void> _updateReceipt(ReceiptSettings next) async {
    setState(() => _receipt = next);
    await SettingsStore.saveReceipt(next);
  }

  void _syncReceiptText() {
    _updateReceipt(
      _receipt.copyWith(
        businessName: _businessNameController.text,
        businessAddress: _businessAddressController.text,
        businessContact: _businessContactController.text,
        footer: _footerController.text,
      ),
    );
  }

  // --- Bluetooth ------------------------------------------------------------

  void _listenToBluetoothState() {
    _adapterSubscription = fbp.FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      final isOn = state == fbp.BluetoothAdapterState.on;
      setState(() => _isBluetoothOn = isOn);
      if (!isOn && _isScanning) {
        _stopScan();
        setState(() => _scanMessage = 'Bluetooth is turned off');
      }
    });
  }

  Future<void> _onScanPressed() async {
    if (!_isBluetoothOn) {
      setState(() => _scanMessage = 'Bluetooth is turned off');
      return;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses.values.any((status) => !status.isGranted)) {
      if (!mounted) return;
      setState(() {
        _scanMessage = 'Bluetooth permission is required to scan for printers.';
      });
      return;
    }

    _startScan();
  }

  void _startScan() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices = [];
      _scanMessage = null;
    });

    _discoverySubscription?.cancel();
    _scanTimer?.cancel();

    // Devices are collected without setState so discovery does not rebuild the
    // page on every stream event; the UI is updated once when the timer fires.
    var found = <BluetoothDevice>[];

    _discoverySubscription = FlutterBluetoothPrinter.discovery.listen(
      (state) {
        if (state is DiscoveryResult) found = state.devices;
      },
      onError: (Object error) {
        LoggerX.log('[SCAN] Discovery error: $error');
        _stopScan();
        if (!mounted) return;
        setState(() => _scanMessage = _notFoundMessage);
      },
    );

    _scanTimer = Timer(_scanDuration, () {
      _discoverySubscription?.cancel();
      _discoverySubscription = null;
      _scanTimer = null;
      if (!mounted) return;

      setState(() {
        _devices = found;
        _isScanning = false;
        _scanMessage = found.isEmpty ? _notFoundMessage : null;
      });
    });
  }

  void _stopScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    if (mounted) setState(() => _isScanning = false);
  }

  static const _notFoundMessage =
      'No printer found. Make sure Bluetooth and your printer are turned on '
      'and paired.';

  // --- Logo -----------------------------------------------------------------

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (picked == null) return;

      // Copy into app storage so the path stays valid after the picker cache
      // is cleared.
      final dir = await getApplicationDocumentsDirectory();
      final target = File(
        '${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await target.writeAsBytes(await picked.readAsBytes());

      await _updateReceipt(_receipt.copyWith(logoPath: target.path));
    } catch (e) {
      LoggerX.log('[LOGO] Failed to pick logo: $e');
      _notify('Failed to load the logo.', isError: true);
    }
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

  void _openPreview() {
    _syncReceiptText();
    ReceiptPreviewSheet.show(
      context,
      order: ReceiptOrder.sample(),
      receiptSettings: _receipt.copyWith(
        businessName: _businessNameController.text,
        businessAddress: _businessAddressController.text,
        businessContact: _businessContactController.text,
        footer: _footerController.text,
      ),
      printerSettings: _printer,
    );
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESCPOS Printer')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) _syncReceiptText();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _printerSection(),
                  const SizedBox(height: 28),
                  _receiptSection(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _openPreview,
                  icon: const Icon(Icons.receipt_long),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Preview Receipt'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  Widget _printerSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Printer Settings'),
        const Text('Paper Size', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '58', label: Text('58mm')),
            ButtonSegment(value: '80', label: Text('80mm')),
          ],
          selected: {_printer.paperSize},
          onSelectionChanged: (selection) =>
              _updatePrinter(_printer.copyWith(paperSize: selection.first)),
        ),
        if (!_isBluetoothOn) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.bluetooth_disabled),
              title: const Text('Bluetooth is turned off'),
              subtitle: const Text(
                'Turn Bluetooth on to scan for and connect a printer.',
              ),
              trailing: TextButton(
                onPressed: () => AppSettings.openAppSettings(
                  type: AppSettingsType.bluetooth,
                ),
                child: const Text('Settings'),
              ),
            ),
          ),
        ],
        if (_printer.address.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text(
                _printer.name.isEmpty ? 'Printer' : _printer.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_printer.address),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isScanning ? null : _onScanPressed,
          icon: const Icon(Icons.search),
          label: Text(_isScanning ? 'Scanning...' : 'Scan Printer'),
        ),
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (_scanMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _scanMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        for (final device in _devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print),
            title: Text(device.name ?? 'Unknown Device'),
            subtitle: Text(device.address),
            selected: device.address == _printer.address,
            trailing: device.address == _printer.address
                ? const Icon(Icons.check_circle)
                : null,
            onTap: () => _updatePrinter(
              _printer.copyWith(
                address: device.address,
                name: device.name ?? '',
              ),
            ),
          ),
      ],
    );
  }

  Widget _receiptSection() {
    final hasCustomLogo = _receipt.logoPath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Receipt Settings'),
        TextField(
          controller: _businessNameController,
          decoration: const InputDecoration(
            labelText: 'Business Name',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: _syncReceiptText,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _businessAddressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: _syncReceiptText,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _businessContactController,
          decoration: const InputDecoration(
            labelText: 'Contact',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: _syncReceiptText,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Print Logo'),
          subtitle: const Text('Show the business logo in the receipt header'),
          value: _receipt.enableLogo,
          onChanged: (value) =>
              _updateReceipt(_receipt.copyWith(enableLogo: value)),
        ),
        if (_receipt.enableLogo)
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                // Border drawn in the foreground so the clipped logo cannot
                // paint over it.
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: hasCustomLogo
                      ? Image.file(File(_receipt.logoPath), fit: BoxFit.contain)
                      : Image.asset('assets/appicon.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose Logo'),
              ),
              if (hasCustomLogo)
                TextButton(
                  onPressed: () =>
                      _updateReceipt(_receipt.copyWith(logoPath: '')),
                  child: const Text('Reset'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _footerController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Receipt Footer',
            helperText: 'Max. 32 characters per line on 58mm paper',
            border: OutlineInputBorder(),
          ),
          onEditingComplete: _syncReceiptText,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transaction QR'),
          subtitle: const Text(
            'Print a QR code in the footer to validate the transaction',
          ),
          value: _receipt.enableQr,
          onChanged: (value) =>
              _updateReceipt(_receipt.copyWith(enableQr: value)),
        ),
      ],
    );
  }
}
