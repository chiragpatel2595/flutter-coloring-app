import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'canvas_painter.dart';
import 'color_picker.dart';
import 'models.dart';
import 'save_image.dart';
import 'templates.dart';

class ColoringPage extends StatefulWidget {
  const ColoringPage({super.key});

  @override
  State<ColoringPage> createState() => _ColoringPageState();
}

class _ColoringPageState extends State<ColoringPage> {
  // One board per template, so each picture remembers its own strokes.
  late final List<Artboard> _boards =
      List.generate(kTemplates.length, (_) => Artboard());

  final GlobalKey _canvasKey = GlobalKey();

  // Strokes being drawn right now, keyed by pointer id. Tracking each pointer
  // separately is what makes multi-touch work: two fingers get two strokes,
  // instead of the second finger hijacking the first finger's line.
  final Map<int, Stroke> _active = {};

  int _page = 0;
  Color _color = Colors.red;
  double _brush = 12;
  bool _erasing = false;
  BrushType _brushType = BrushType.pen;

  // For the spray brush's random scatter (see _pointsAt).
  final math.Random _rng = math.Random();

  Artboard get _board => _boards[_page];

  // (name, color) pairs — the name is used for tooltips and screen readers.
  static const _palette = <(String, Color)>[
    ('Red', Colors.red),
    ('Orange', Colors.orange),
    ('Yellow', Colors.yellow),
    ('Green', Colors.green),
    ('Blue', Colors.blue),
    ('Purple', Colors.purple),
    ('Brown', Colors.brown),
    ('Black', Colors.black),
  ];

  // Colors the user mixed with the custom picker, shown as extra swatches.
  final List<Color> _customColors = [];

  // ---- Pointer handling (one stroke per active pointer) ----

  /// Turns a pixel position into a 0..1 fraction of the canvas so strokes
  /// scale with the canvas on resize. See [Stroke].
  Offset _normalize(Offset p, Size size) => Offset(
        size.width == 0 ? 0 : p.dx / size.width,
        size.height == 0 ? 0 : p.dy / size.height,
      );

  /// The point(s) to add for a touch at [local]. Most brushes add a single
  /// point; the spray brush bakes a small burst of scattered points around it
  /// (radius = brush size) so the airbrush look is stable across repaints.
  List<Offset> _pointsAt(Offset local, Size size) {
    if (_erasing || _brushType != BrushType.spray) {
      return [_normalize(local, size)];
    }
    return List.generate(6, (_) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final dist = _rng.nextDouble() * _brush;
      final p = local + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      return _normalize(p, size);
    });
  }

  void _startStroke(int pointer, Offset local, Size size) => setState(() {
        _board.redo.clear(); // a fresh stroke invalidates the redo history
        final stroke = Stroke(
          // The eraser ignores brush type; store pen so it paints a plain line.
          type: _erasing ? BrushType.pen : _brushType,
          color: _color,
          width: _brush,
          erase: _erasing,
          points: _pointsAt(local, size),
        );
        _active[pointer] = stroke;
        _board.strokes.add(stroke);
      });

  void _extendStroke(int pointer, Offset local, Size size) {
    final stroke = _active[pointer];
    if (stroke == null) return;
    setState(() => stroke.points.addAll(_pointsAt(local, size)));
  }

  void _endStroke(int pointer) => _active.remove(pointer);

  // ---- Toolbar actions ----

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

  /// Clear wipes both the strokes and the redo history, so it can't be undone.
  /// Because it's destructive, ask first.
  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear picture?'),
        content: const Text(
            "This erases everything on this page and can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _board.strokes.clear();
      _board.redo.clear();
    });
  }

  void _goTo(int delta) => setState(() {
        _page = (_page + delta).clamp(0, kTemplates.length - 1);
      });

  /// Opens the custom color picker; the chosen color becomes active and is
  /// remembered as a new swatch.
  Future<void> _pickCustomColor() async {
    final picked = await showColorPickerDialog(context, _color);
    if (picked == null || !mounted) return;
    setState(() {
      _erasing = false;
      _color = picked;
      if (!_customColors.contains(picked) &&
          !_palette.any((e) => e.$2 == picked)) {
        _customColors.add(picked);
      }
    });
  }

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
      final safeName = kTemplates[_page].name.toLowerCase().replaceAll(' ', '_');
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

    // Desktop/web keyboard shortcuts. Ctrl+Z / Cmd+Z undo, add Shift (or
    // Ctrl+Y) to redo.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (canUndo) _undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          if (canUndo) _undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            () {
          if (canRedo) _redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            () {
          if (canRedo) _redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (canRedo) _redo();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(kTemplates[_page].name),
            actions: [
              IconButton(
                tooltip: 'Undo (Ctrl+Z)',
                icon: const Icon(Icons.undo),
                onPressed: canUndo ? _undo : null,
              ),
              IconButton(
                tooltip: 'Redo (Ctrl+Shift+Z)',
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
                // Nothing drawn yet -> nothing worth saving.
                onPressed: canUndo ? _save : null,
              ),
            ],
          ),
          body: Column(
            children: [
              // ---- Drawing canvas ----
              Expanded(
                child: RepaintBoundary(
                  key: _canvasKey,
                  // LayoutBuilder hands us the live canvas size so we can
                  // normalize pointer positions against it.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return MouseRegion(
                        cursor: SystemMouseCursors.precise,
                        // Raw pointer events (not GestureDetector's pan) so we
                        // can track each finger independently for multi-touch.
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) =>
                              _startStroke(e.pointer, e.localPosition, size),
                          onPointerMove: (e) =>
                              _extendStroke(e.pointer, e.localPosition, size),
                          onPointerUp: (e) => _endStroke(e.pointer),
                          onPointerCancel: (e) => _endStroke(e.pointer),
                          child: CustomPaint(
                            painter: CanvasPainter(
                                _board.strokes, kTemplates[_page]),
                            size: Size.infinite,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // ---- Tools ----
              _buildToolbar(),
            ],
          ),
        ),
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
                  '${kTemplates[_page].name}  (${_page + 1}/${kTemplates.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: 'Next picture',
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      _page == kTemplates.length - 1 ? null : () => _goTo(1),
                ),
              ],
            ),
            // color swatches + custom colors + add-color + eraser
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in _palette) _swatch(entry.$1, entry.$2),
                  for (final c in _customColors)
                    _swatch('Custom color', c),
                  _addColorButton(),
                  _eraserButton(),
                ],
              ),
            ),
            // brush type selector
            _brushTypeSelector(),
            // brush size slider + a live preview of the current tool/size
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
                const SizedBox(width: 8),
                _brushPreview(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Icon-only segmented control for choosing the brush type. Choosing one
  /// also turns the eraser off; while erasing, no brush is highlighted.
  Widget _brushTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<BrushType>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(
                value: BrushType.pen, icon: Icon(Icons.edit), tooltip: 'Pen'),
            ButtonSegment(
                value: BrushType.marker,
                icon: Icon(Icons.brush),
                tooltip: 'Marker'),
            ButtonSegment(
                value: BrushType.highlighter,
                icon: Icon(Icons.border_color),
                tooltip: 'Highlighter'),
            ButtonSegment(
                value: BrushType.spray,
                icon: Icon(Icons.blur_on),
                tooltip: 'Spray'),
          ],
          selected: _erasing ? const <BrushType>{} : {_brushType},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() {
              _brushType = selection.first;
              _erasing = false;
            });
          },
        ),
      ),
    );
  }

  Widget _swatch(String name, Color c) {
    final selected = !_erasing && c == _color;
    // Tooltip + Semantics give the color a name for hover and screen readers;
    // InkResponse makes it keyboard-focusable and activatable (unlike a bare
    // GestureDetector).
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name color',
        child: InkResponse(
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
        ),
      ),
    );
  }

  Widget _addColorButton() {
    return Tooltip(
      message: 'Custom color',
      child: Semantics(
        button: true,
        label: 'Add a custom color',
        child: InkResponse(
          onTap: _pickCustomColor,
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              gradient: const SweepGradient(colors: [
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _eraserButton() {
    return Tooltip(
      message: 'Eraser',
      child: Semantics(
        button: true,
        selected: _erasing,
        label: 'Eraser',
        child: InkResponse(
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
        ),
      ),
    );
  }

  /// A dot showing the current brush size and color (or a hollow circle for
  /// the eraser), so you can see the tool before touching the canvas.
  Widget _brushPreview() {
    return Semantics(
      label: _erasing ? 'Eraser preview' : 'Brush preview',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: _brush,
            height: _brush,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _erasing ? Colors.white : _color,
              border: Border.all(color: Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}
