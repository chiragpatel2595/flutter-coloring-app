import 'package:flutter/material.dart';
import 'dart:ui' show PointMode;

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

/// One continuous finger/mouse stroke: a color, a width, and the points it covers.
class Stroke {
  final Color color;
  final double width;
  final List<Offset> points;
  Stroke(this.color, this.width, this.points);
}

class ColoringPage extends StatefulWidget {
  const ColoringPage({super.key});

  @override
  State<ColoringPage> createState() => _ColoringPageState();
}

class _ColoringPageState extends State<ColoringPage> {
  final List<Stroke> _strokes = [];
  Color _color = Colors.red;
  double _brush = 12;
  bool _erasing = false;

  static const _palette = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.brown,
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coloring Practice'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed:
                _strokes.isEmpty ? null : () => setState(_strokes.removeLast),
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline),
            onPressed:
                _strokes.isEmpty ? null : () => setState(_strokes.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Drawing canvas ----
          Expanded(
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanStart: (d) => setState(() {
                  _strokes.add(Stroke(
                    _erasing ? Colors.white : _color,
                    _brush,
                    [d.localPosition],
                  ));
                }),
                onPanUpdate: (d) => setState(() {
                  _strokes.last.points.add(d.localPosition);
                }),
                child: CustomPaint(
                  painter: _CanvasPainter(_strokes),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // ---- Tools ----
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // color swatches + eraser
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in _palette) _swatch(c),
                  _eraserButton(),
                ],
              ),
            ),
            // brush size slider
            Row(
              children: [
                const Icon(Icons.brush, size: 18),
                Expanded(
                  child: Slider(
                    min: 2,
                    max: 40,
                    value: _brush,
                    label: _brush.round().toString(),
                    divisions: 38,
                    onChanged: (v) => setState(() => _brush = v),
                  ),
                ),
                Text('${_brush.round()}px'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color c) {
    final selected = !_erasing && c == _color;
    return GestureDetector(
      onTap: () => setState(() {
        _color = c;
        _erasing = false;
      }),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Widget _eraserButton() {
    return GestureDetector(
      onTap: () => setState(() => _erasing = true),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _erasing ? Colors.black : Colors.black26,
            width: _erasing ? 3 : 1,
          ),
        ),
        child: const Icon(Icons.cleaning_services, size: 18),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  _CanvasPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        // a single tap -> draw a dot
        canvas.drawPoints(PointMode.points, s.points, paint);
      } else {
        final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
        for (final p in s.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
