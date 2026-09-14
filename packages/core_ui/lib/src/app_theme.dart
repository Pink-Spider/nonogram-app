import 'package:flutter/material.dart';

import 'puzzle_colors.dart';

/// Material 3 themes with the puzzle palette attached.
class AppTheme {
  const AppTheme._();

  static ThemeData light({Color seed = const Color(0xFF1565C0)}) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        extensions: const [PuzzleColors.light],
      );

  static ThemeData dark({Color seed = const Color(0xFF1565C0)}) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        extensions: const [PuzzleColors.dark],
      );
}
