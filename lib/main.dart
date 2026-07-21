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
        scaffoldBackgroundColor: KidPalette.paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KidPalette.kraft,
          surface: KidPalette.paper,
        ),
        // Flat and papery — no drop shadows or tinted elevation, so the toolbar
        // reads as a table the crayons sit on rather than a floating panel.
        appBarTheme: const AppBarTheme(
          backgroundColor: KidPalette.paper,
          foregroundColor: KidPalette.cocoa,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: KidPalette.cocoa,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        // Big icons and big hit areas: small children have coarse aim.
        iconTheme: const IconThemeData(color: KidPalette.cocoa, size: 30),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(52, 52),
            foregroundColor: KidPalette.cocoa,
            disabledForegroundColor: KidPalette.cocoaSoft,
          ),
        ),
      ),
      home: const ColoringPage(),
    );
  }
}
