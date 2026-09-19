import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// Debug-only logger that chunks long messages so they are not truncated.
class LoggerX {
  LoggerX._();

  static void log(String text) {
    if (!kDebugMode) return;
    for (final match in RegExp('.{1,800}').allMatches(text)) {
      dev.log(match.group(0) ?? '');
    }
  }
}
