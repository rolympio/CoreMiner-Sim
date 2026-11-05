import 'package:flutter/material.dart';

class CoreMinerTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E2022),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F4C81), brightness: Brightness.dark),
  );
}
