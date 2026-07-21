import 'package:flutter/material.dart';

import 'coloring_page.dart';
import 'kid_palette.dart';

void main() => runApp(const ColoringApp());

class ColoringApp extends StatelessWidget {
  const ColoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coloring Practice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: KidPalette.table,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KidPalette.primary,
          surface: KidPalette.toolbar,
          error: KidPalette.error,
        ),
        // The app bar shares the table color so the frame around the paper is
        // one continuous colored surface, top to bottom.
        appBarTheme: const AppBarTheme(
          backgroundColor: KidPalette.table,
          foregroundColor: KidPalette.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: KidPalette.ink,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        // Big icons and big hit areas: small children have coarse aim.
        iconTheme: const IconThemeData(color: KidPalette.ink, size: 30),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(52, 52),
            foregroundColor: KidPalette.ink,
            disabledForegroundColor: KidPalette.outline,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const ColoringPage(),
    );
  }
}
