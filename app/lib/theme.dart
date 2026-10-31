import 'package:flutter/material.dart';

const _seed = Color(0xFF0F766E); // teal-700

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const buttonSize = Size(64, 48);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surfaceContainerLowest, scrolledUnderElevation: 1),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: buttonSize)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: buttonSize)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerLow,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(shape: rounded.copyWith(borderRadius: BorderRadius.circular(24))),
  );
}
