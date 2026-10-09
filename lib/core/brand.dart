import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// White-label settings. Change these to rebrand the whole app for a buyer.
class Brand {
  static const name = 'Wayo';
  static const tagline = 'Premium mobility, beautifully simple';
  static const currency = '\$';
  static const commission = 0.20; // platform cut of each fare
  static const city = 'New York';
  static const cityCenter = LatLng(40.7128, -74.0060);

  /// Public OpenStreetMap tiles for the prototype. No API key is required.
  /// This keeps the web build working immediately without MapTiler credentials.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'com.wayo.rides';
}

class AppColors {
  static const primary = Color(0xFF171717);
  static const primaryDark = Color(0xFF070707);
  static const accent = Color(0xFF5F6368);
  static const bg = Color(0xFFF6F5F2);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF77736C);
  static const danger = Color(0xFFD64545);
  static const ok = Color(0xFF2E9E5B);
  static const info = Color(0xFF536B82);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withAlpha(25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withAlpha(25)),
      ),
    ),
  );
}
