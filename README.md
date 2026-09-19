# ESCPOS Printer

Aplikasi Flutter (Android) untuk mencetak struk ke printer thermal Bluetooth menggunakan perintah ESC/POS. Aplikasi ini berfungsi sebagai demo/starter: data pesanan dibuat di memori (`ReceiptOrder.sample()`), tanpa database atau backend POS.

## Fitur

- **Scan & pilih printer Bluetooth** — pemindaian perangkat di sekitar, termasuk pengecekan izin lokasi/Bluetooth dan status adapter.
- **Dukungan kertas 58 mm & 80 mm** — lebar kolom (32/48) dan lebar dot (360/560) menyesuaikan otomatis.
- **Pengaturan struk** — nama usaha, alamat, kontak, teks footer, logo kustom (dipilih dari galeri), serta opsi aktif/nonaktif logo dan QR.
- **Preview struk** — struk dirender menjadi gambar JPEG dan ditampilkan di bottom sheet sebelum dicetak.
- **Cetak ESC/POS** — header (bitmap logo + identitas usaha), body teks monospace, footer (teks + QR), lalu feed dan partial cut. Tiap bagian dikirim terpisah agar printer sempat merasterisasi bitmap.
- **Bagikan struk** — ekspor hasil render sebagai gambar lewat share sheet sistem.
- **QR validasi** — payload deterministik `{noStruk}-{yyyyMMddHHmmss}-{total}-{hash}` dengan potongan digest SHA-256.
- **Penyimpanan pengaturan** — semua konfigurasi printer dan struk disimpan di `SharedPreferences`.

## Struktur Proyek

```
lib/
  main.dart                      # Entry point, MaterialApp + tema
  models/receipt_order.dart      # Model pesanan, item, modifier, kalkulasi total
  services/
    printer_service.dart         # Pengiriman data ESC/POS ke printer Bluetooth
    receipt_renderer.dart        # Render struk ke JPEG, payload QR, share
    receipt_graphics.dart        # Gambar header & footer (logo, QR)
    receipt_text_builder.dart    # Penyusunan teks struk
    receipt_text_layout.dart     # Utilitas layout kolom monospace
    settings_store.dart          # PrinterSettings & ReceiptSettings + persistensi
  theme/app_theme.dart           # Tema terang/gelap
  utils/                         # Format mata uang, logger
  views/
    home_page.dart               # Halaman pengaturan printer & struk
    receipt_preview_sheet.dart   # Preview, tombol cetak dan bagikan
test/                            # Unit test layout teks & format mata uang
```

## Paket Utama

`flutter_bluetooth_printer`, `esc_pos_utils_plus`, `flutter_blue_plus`, `permission_handler`, `image`, `image_picker`, `qr`, `shared_preferences`, `path_provider`, `share_plus`, `intl`, `crypto`.

## Menjalankan

```bash
flutter pub get
flutter run
```

Regenerasi ikon dan splash screen:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Menjalankan test:

```bash
flutter test
```

## Cara Pakai

1. Aktifkan Bluetooth dan berikan izin yang diminta aplikasi.
2. Tekan tombol scan, lalu pilih printer thermal dari daftar perangkat.
3. Pilih ukuran kertas (58 mm atau 80 mm).
4. Isi data usaha, footer, dan logo pada bagian pengaturan struk.
5. Tekan **Preview Receipt**, lalu cetak atau bagikan hasilnya.

## Catatan

- Target utama adalah Android (SDK minimum 21). Konfigurasi splash/ikon hanya diaktifkan untuk Android.
- Data pesanan pada demo bersifat statis; ganti `ReceiptOrder.sample()` dengan data nyata untuk integrasi ke sistem POS.
