import 'package:flutter/material.dart';

import 'coloring_page.dart';

void main() => runApp(const ColoringApp());

class ColoringApp extends StatelessWidget {
  const ColoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coloring Practice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.purple),
      home: const ColoringPage(),
    );
  }
}
