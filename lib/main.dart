import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'views/home_page.dart';

void main() {
  runApp(const EscposPrinterApp());
}

class EscposPrinterApp extends StatelessWidget {
  const EscposPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESCPOS Printer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
