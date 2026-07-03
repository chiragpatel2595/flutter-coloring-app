import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import 'save_image.dart';

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

/// One continuous finger/mouse stroke: a color, a width, whether it erases,
/// and the points it covers.
class Stroke {
  final Color color;
  final double width;
  final bool erase;
  final List<Offset> points;
  Stroke({
    required this.color,
    required this.width,
    required this.erase,
    required this.points,
  });
}

/// A coloring picture: a name plus an optional outline to draw as the
/// (non-erasable) background. A null [drawOutline] means a blank canvas.
typedef OutlineDrawer = void Function(Canvas canvas, Size size);

class ColoringTemplate {
  final String name;
  final OutlineDrawer? drawOutline;
  const ColoringTemplate(this.name, this.drawOutline);
}

/// The strokes (and redo history) for a single picture. Each template gets
/// its own board so switching pictures keeps their artwork.
class _Artboard {
  final List<Stroke> strokes = [];
  final List<Stroke> redo = [];
}

class ColoringPage extends StatefulWidget {
  const ColoringPage({super.key});

  @override
  State<ColoringPage> createState() => _ColoringPageState();
}

class _ColoringPageState extends State<ColoringPage> {
  // The pictures you can color. Vector outlines keep the app package- and
  // asset-free; add more templates by writing another top-level drawer below.
  static const _templates = <ColoringTemplate>[
    ColoringTemplate('Blank', null),
    ColoringTemplate('Fish', _drawFish),
    ColoringTemplate('Flower', _drawFlower),
    ColoringTemplate('House', _drawHouse),
    ColoringTemplate('Star', _drawStar),
  ];

  // One board per template, so each picture remembers its own strokes.
  late final List<_Artboard> _boards =
      List.generate(_templates.length, (_) => _Artboard());

  final GlobalKey _canvasKey = GlobalKey();

  int _page = 0;
  Color _color = Colors.red;
  double _brush = 12;
  bool _erasing = false;

  _Artboard get _board => _boards[_page];

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

  void _undo() => setState(() {
        if (_board.strokes.isNotEmpty) {
          _board.redo.add(_board.strokes.removeLast());
        }
      });

  void _redo() => setState(() {
        if (_board.redo.isNotEmpty) {
          _board.strokes.add(_board.redo.removeLast());
        }
      });

  void _clear() => setState(() {
        _board.strokes.clear();
        _board.redo.clear();
      });

  void _goTo(int delta) => setState(() {
        _page = (_page + delta).clamp(0, _templates.length - 1);
      });

  /// Captures the canvas as a PNG and hands it to the platform saver.
  Future<void> _save() async {
    // Grab the messenger before the first await so we don't touch `context`
    // across an async gap.
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not capture the canvas.')),
        );
        return;
      }
      final safeName =
          _templates[_page].name.toLowerCase().replaceAll(' ', '_');
      final msg = await savePng(
        byteData.buffer.asUint8List(),
        'coloring_$safeName.png',
      );
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = _board.strokes.isNotEmpty;
    final canRedo = _board.redo.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_templates[_page].name),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? _undo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: canRedo ? _redo : null,
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline),
            onPressed: canUndo ? _clear : null,
          ),
          IconButton(
            tooltip: 'Save picture',
            icon: const Icon(Icons.save_alt),
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Drawing canvas ----
          Expanded(
            child: RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() {
                  _board.redo.clear();
                  _board.strokes.add(Stroke(
                    color: _color,
                    width: _brush,
                    erase: _erasing,
                    points: [d.localPosition],
                  ));
                }),
                onPanUpdate: (d) => setState(() {
                  _board.strokes.last.points.add(d.localPosition);
                }),
                child: CustomPaint(
                  painter: _CanvasPainter(_board.strokes, _templates[_page]),
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
            // picture navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous picture',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page == 0 ? null : () => _goTo(-1),
                ),
                Text(
                  '${_templates[_page].name}  (${_page + 1}/${_templates.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: 'Next picture',
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      _page == _templates.length - 1 ? null : () => _goTo(1),
                ),
              ],
            ),
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
  final ColoringTemplate template;
  _CanvasPainter(this.strokes, this.template);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Opaque white background.
    canvas.drawRect(bounds, Paint()..color = Colors.white);

    // Outline goes *under* the user's paint layer so the eraser reveals it
    // instead of wiping it out.
    template.drawOutline?.call(canvas, size);

    // Paint the user's strokes into their own layer. The eraser then uses
    // BlendMode.clear to punch real holes back to the outline/background,
    // rather than the old trick of painting white.
    canvas.saveLayer(bounds, Paint());
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;

      if (s.points.length == 1) {
        // a single tap -> draw a dot
        canvas.drawPoints(ui.PointMode.points, s.points, paint);
      } else {
        final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
        for (final p in s.points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  // Strokes are mutated in place (same list instance) as you draw, so we can't
  // detect changes by reference — always repaint. See the caching idea in
  // CLAUDE.md's next steps if this ever gets expensive.
  bool shouldRepaint(_CanvasPainter old) => true;
}

// ---------------------------------------------------------------------------
// Outline templates. Each strokes a simple, recognizable shape scaled into a
// centered box, so the same picture works on any screen size.
// ---------------------------------------------------------------------------

Paint _outlinePaint() => Paint()
  ..color = Colors.black
  ..style = PaintingStyle.stroke
  ..strokeWidth = 4
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// A centered square box covering ~70% of the smaller dimension.
Rect _box(Size size) {
  final side = math.min(size.width, size.height) * 0.7;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: side,
    height: side,
  );
}

void _drawFish(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final cy = b.center.dy;
  final body =
      Rect.fromCenter(center: b.center, width: b.width * 0.8, height: b.height * 0.5);
  canvas.drawOval(body, p);
  // tail fin
  final tail = Path()
    ..moveTo(body.right - 2, cy)
    ..lineTo(b.right, cy - b.height * 0.18)
    ..lineTo(b.right, cy + b.height * 0.18)
    ..close();
  canvas.drawPath(tail, p);
  // eye
  canvas.drawCircle(
      Offset(body.left + b.width * 0.18, cy - b.height * 0.06), b.width * 0.03, p);
}

void _drawFlower(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final c = Offset(b.center.dx, b.top + b.height * 0.3);
  final petalR = b.width * 0.12;
  final ringR = b.width * 0.2;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    canvas.drawCircle(
        Offset(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a)), petalR, p);
  }
  canvas.drawCircle(c, petalR, p); // flower center
  // stem + leaf
  canvas.drawLine(Offset(c.dx, c.dy + ringR + petalR), Offset(c.dx, b.bottom), p);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(c.dx + b.width * 0.1, b.bottom - b.height * 0.15),
      width: b.width * 0.18,
      height: b.height * 0.08,
    ),
    p,
  );
}

void _drawHouse(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final wallTop = b.top + b.height * 0.4;
  final wall = Rect.fromLTRB(
      b.left + b.width * 0.1, wallTop, b.right - b.width * 0.1, b.bottom);
  canvas.drawRect(wall, p);
  // roof
  final roof = Path()
    ..moveTo(wall.left - b.width * 0.05, wallTop)
    ..lineTo(b.center.dx, b.top)
    ..lineTo(wall.right + b.width * 0.05, wallTop)
    ..close();
  canvas.drawPath(roof, p);
  // door
  canvas.drawRect(
    Rect.fromLTWH(b.center.dx - b.width * 0.08, b.bottom - b.height * 0.22,
        b.width * 0.16, b.height * 0.22),
    p,
  );
  // window
  canvas.drawRect(
    Rect.fromLTWH(wall.left + b.width * 0.08, wallTop + b.height * 0.06,
        b.width * 0.14, b.height * 0.12),
    p,
  );
}

void _drawStar(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final c = b.center;
  final outer = b.width / 2;
  final inner = outer * 0.4;
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  canvas.drawPath(path, p);
}
