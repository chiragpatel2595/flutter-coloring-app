import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'canvas_painter.dart';
import 'color_picker.dart';
import 'crayon.dart';
import 'flood_fill.dart';
import 'kid_palette.dart';
import 'models.dart';
import 'save_image.dart';
import 'templates.dart';

class ColoringPage extends StatefulWidget {
  const ColoringPage({super.key});

  @override
  State<ColoringPage> createState() => _ColoringPageState();
}

class _ColoringPageState extends State<ColoringPage>
    with SingleTickerProviderStateMixin {
  // A single board — the app shows one picture for now. When per-picture
  // navigation comes back this becomes a list keyed by template again, so that
  // each picture keeps its own strokes and undo history.
  final Artboard _board = Artboard();

  // ---- "Pop" animation: the stroke you just finished briefly swells ----
  // The controller drives a 0 → 1 value over its duration; CanvasPainter turns
  // that into a width multiplier. Created in initState and released in
  // dispose — an AnimationController holds a ticker that fires every frame, so
  // leaving it undisposed would keep this screen alive after it's gone.
  late final AnimationController _popController;
  Stroke? _popStroke;

  @override
  void initState() {
    super.initState();
    _popController =
        AnimationController(
          vsync:
              this, // SingleTickerProviderStateMixin supplies the frame clock
          duration: const Duration(milliseconds: 320),
        )..addStatusListener((status) {
          // Once the pop finishes, forget the stroke so it paints at its normal
          // width again (and so we don't hold on to it forever).
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _popStroke = null);
          }
        });
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  final GlobalKey _canvasKey = GlobalKey();

  // Strokes being drawn right now, keyed by pointer id. Tracking each pointer
  // separately is what makes multi-touch work: two fingers get two strokes,
  // instead of the second finger hijacking the first finger's line.
  final Map<int, Stroke> _active = {};

  Color _color = Colors.red;
  double _brush = kBrushSizes[1].$2; // "Medium" — must match a preset exactly,
  // since the size picker highlights by value equality.
  bool _erasing = false;
  bool _filling = false; // paint-bucket tool active
  BrushType _brushType = BrushType.pen;

  // For the spray brush's random scatter (see _pointsAt).
  final math.Random _rng = math.Random();

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
    _clearRedo(); // a fresh stroke invalidates the redo history
    final stroke = Stroke(
      // The eraser ignores brush type; store pen so it paints a plain line.
      type: _erasing ? BrushType.pen : _brushType,
      color: _color,
      width: _brush,
      erase: _erasing,
      points: _pointsAt(local, size),
    );
    _active[pointer] = stroke;
    _board.layers.add(stroke);
  });

  void _extendStroke(int pointer, Offset local, Size size) {
    final stroke = _active[pointer];
    if (stroke == null) return;
    setState(() => stroke.points.addAll(_pointsAt(local, size)));
  }

  void _endStroke(int pointer) {
    final stroke = _active.remove(pointer);
    // Nothing to celebrate for an eraser swipe — a swelling hole looks wrong.
    if (stroke == null || stroke.erase) return;
    setState(() => _popStroke = stroke);
    _popController.forward(from: 0); // restart, even if a pop was mid-flight
  }

  // ---- Paint bucket (flood fill) ----

  /// Fills the contiguous region around [local] with the current color.
  ///
  /// It rasterizes the current canvas, runs a scan-free flood fill over the
  /// pixels (matching colors near the tapped pixel, stopping at the outline
  /// and other colors), bakes the result to a transparent [ui.Image], and adds
  /// it as a [Fill] layer. Pixel work on the main thread — fine for a tap on a
  /// phone-sized canvas; see CLAUDE.md if it ever needs an isolate.
  Future<void> _floodFill(Offset local, Size size) async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1);
    final w = image.width, h = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return;
    final src = byteData.buffer.asUint8List();

    final sx = local.dx.round().clamp(0, w - 1);
    final sy = local.dy.round().clamp(0, h - 1);

    // Heavy pixel work lives in the pure, unit-tested floodFill(). It returns
    // null when the tapped region is already this color.
    final out = floodFill(src, w, h, sx, sy, _color.toARGB32(), 48);
    if (out == null) return;

    final fillImage = await _decodePixels(out, w, h);
    if (!mounted) {
      fillImage.dispose();
      return;
    }
    setState(() {
      _clearRedo();
      _board.layers.add(Fill(fillImage));
    });
  }

  Future<ui.Image> _decodePixels(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  // ---- Toolbar actions ----

  void _undo() => setState(() {
    if (_board.layers.isNotEmpty) {
      _board.redo.add(_board.layers.removeLast());
    }
  });

  void _redo() => setState(() {
    if (_board.redo.isNotEmpty) {
      _board.layers.add(_board.redo.removeLast());
    }
  });

  /// Empties the redo history, disposing any fill images in it (they can't be
  /// reached again, so free their native memory).
  void _clearRedo() {
    for (final layer in _board.redo) {
      if (layer is Fill) layer.dispose();
    }
    _board.redo.clear();
  }

  /// Clear wipes both the layers and the redo history, so it can't be undone.
  /// Because it's destructive, ask first.
  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear picture?'),
        content: const Text(
          "This erases everything on this page and can't be undone.",
        ),
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
      for (final layer in [..._board.layers, ..._board.redo]) {
        if (layer is Fill) layer.dispose();
      }
      _board.layers.clear();
      _board.redo.clear();
    });
  }

  /// Opens the custom color picker; the chosen color becomes active and is
  /// remembered as a new swatch.
  Future<void> _pickCustomColor() async {
    final picked = await showColorPickerDialog(context, _color);
    if (picked == null || !mounted) return;
    setState(() {
      _erasing = false;
      _filling = false;
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
      final boundary =
          _canvasKey.currentContext!.findRenderObject()
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
      final safeName = kActiveTemplate.name.toLowerCase().replaceAll(' ', '_');
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
    final canUndo = _board.layers.isNotEmpty;
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
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () {
          if (canRedo) _redo();
        },
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): () {
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
            title: Text(kActiveTemplate.name),
            actions: [
              IconButton(
                tooltip: 'Undo (Ctrl+Z)',
                icon: const Icon(Icons.undo),
                onPressed: canUndo ? _undo : null,
              ),
              // No redo button: it needs a history-stack mental model that a
              // small child doesn't have, and it sits disabled most of the
              // time. The keyboard shortcut below still works for grown-ups.
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
                          onPointerDown: (e) {
                            // The bucket is a single-tap tool; everything else
                            // starts a stroke.
                            if (_filling) {
                              _floodFill(e.localPosition, size);
                            } else {
                              _startStroke(e.pointer, e.localPosition, size);
                            }
                          },
                          onPointerMove: (e) =>
                              _extendStroke(e.pointer, e.localPosition, size),
                          onPointerUp: (e) => _endStroke(e.pointer),
                          onPointerCancel: (e) => _endStroke(e.pointer),
                          // AnimatedBuilder rebuilds just this subtree on every
                          // frame of the pop, so we get the animation without
                          // calling setState 60 times a second.
                          child: AnimatedBuilder(
                            animation: _popController,
                            builder: (context, _) => CustomPaint(
                              painter: CanvasPainter(
                                _board.layers,
                                kActiveTemplate,
                                popStroke: _popStroke,
                                popT: _popController.value,
                              ),
                              size: Size.infinite,
                            ),
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
      // The selected size dot scales up past its box, so the bottom padding
      // keeps it clear of the system navigation bar.
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      color: KidPalette.paper,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _crayonTray(),
            const SizedBox(height: 8),
            // Brushes on the left, the non-brush tools on the right. Keeping
            // them on one row leaves more of the screen for the picture.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _brushTypeSelector()),
                Row(children: [_bucketButton(), _eraserButton()]),
              ],
            ),
            const SizedBox(height: 6),
            _sizePicker(),
          ],
        ),
      ),
    );
  }

  /// The colors, drawn as crayons standing in a cardboard tray.
  ///
  /// Nothing but crayons lives in here. The tray scrolls horizontally, so any
  /// button parked at its ends would be taken for a scroll control — the
  /// picture arrows sit up in the app bar beside the name instead.
  ///
  /// The tray is padded at the top so the chosen crayon has room to rise into
  /// it — no clipping, and the crayons sit on the tray floor via
  /// [CrossAxisAlignment.end]. The "add a color" button rides at the end of the
  /// row so new colors appear right where you'd reach for them.
  Widget _crayonTray() {
    return Container(
      height: Crayon.height + Crayon.liftRoom + 16,
      decoration: BoxDecoration(
        color: KidPalette.kraft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KidPalette.kraftDark, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in _palette)
              Crayon(
                name: entry.$1,
                color: entry.$2,
                selected: !_erasing && entry.$2 == _color,
                onTap: () => _pickColor(entry.$2),
              ),
            for (final c in _customColors)
              Crayon(
                name: 'Custom color',
                color: c,
                selected: !_erasing && c == _color,
                onTap: () => _pickColor(c),
              ),
            _addColorButton(),
          ],
        ),
      ),
    );
  }

  void _pickColor(Color c) => setState(() {
    _color = c;
    _erasing = false;
    _filling = false;
  });

  /// The four brush sizes, shown as dots you can compare by eye.
  Widget _sizePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [for (final (name, size) in kBrushSizes) _sizeDot(name, size)],
    );
  }

  Widget _sizeDot(String name, double size) {
    final selected = _brush == size;
    // The dot shows the real brush color, so this row doubles as the preview
    // the old slider needed a separate swatch for. Scaled down to fit, but
    // still ordered small → big so the comparison holds.
    final diameter = 8 + size * 0.55;
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name brush',
        child: InkResponse(
          onTap: () => setState(() => _brush = size),
          radius: 30,
          child: AnimatedScale(
            scale: selected ? 1.15 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            child: Container(
              width: 58,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? KidPalette.kraft : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? KidPalette.cocoa : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _erasing ? Colors.white : _color,
                  border: Border.all(color: KidPalette.cocoa, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The four brush types as separate chunky buttons.
  ///
  /// A [SegmentedButton] packs them into one joined pill with thin dividers —
  /// fine for a settings screen, but the segments are small and hard to hit.
  /// Separate buttons give each brush its own generous target.
  Widget _brushTypeSelector() {
    const brushes = <(String, IconData, BrushType)>[
      ('Pen', Icons.edit, BrushType.pen),
      ('Marker', Icons.brush, BrushType.marker),
      ('Highlighter', Icons.border_color, BrushType.highlighter),
      ('Spray', Icons.blur_on, BrushType.spray),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (name, icon, type) in brushes)
            _chunkyButton(
              tooltip: name,
              semanticLabel: '$name brush',
              icon: icon,
              // While erasing or filling, no brush is highlighted.
              selected: !_erasing && !_filling && _brushType == type,
              onTap: () => setState(() {
                _brushType = type;
                _erasing = false;
                _filling = false;
              }),
            ),
        ],
      ),
    );
  }

  /// A big rounded tool button. Selected ones fill with cardboard and spring
  /// up a little, matching how a picked crayon behaves.
  Widget _chunkyButton({
    required String tooltip,
    required String semanticLabel,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color? fill,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: InkResponse(
          onTap: onTap,
          radius: 30,
          child: AnimatedScale(
            scale: selected ? 1.1 : 1,
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            child: Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill ?? (selected ? KidPalette.kraft : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? KidPalette.cocoa : KidPalette.cocoaSoft,
                  width: selected ? 3 : 2,
                ),
              ),
              child: Icon(icon, size: 26, color: iconColor ?? KidPalette.cocoa),
            ),
          ),
        ),
      ),
    );
  }

  /// An empty rainbow slot at the end of the tray — "mix your own crayon".
  /// Sized to match a crayon so the row reads as one set of choices.
  Widget _addColorButton() {
    return Tooltip(
      message: 'Custom color',
      child: Semantics(
        button: true,
        label: 'Add a custom color',
        child: InkResponse(
          onTap: _pickCustomColor,
          radius: Crayon.width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: Crayon.width,
              height: Crayon.height * 0.72,
              decoration: BoxDecoration(
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KidPalette.cocoa, width: 1.5),
              ),
              child: const Icon(Icons.add, size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  /// Paint-bucket toggle. The button fills with the current [_color] so you can
  /// see what tapping the picture would pour on.
  Widget _bucketButton() {
    return _chunkyButton(
      tooltip: 'Fill (paint bucket)',
      semanticLabel: 'Paint bucket fill',
      icon: Icons.format_color_fill,
      selected: _filling,
      fill: _color,
      // Keep the icon legible on both a pale yellow and a near-black fill.
      iconColor: _color.computeLuminance() > 0.5
          ? KidPalette.cocoa
          : Colors.white,
      onTap: () => setState(() {
        _filling = true;
        _erasing = false;
      }),
    );
  }

  Widget _eraserButton() {
    return _chunkyButton(
      tooltip: 'Eraser',
      semanticLabel: 'Eraser',
      icon: Icons.cleaning_services,
      selected: _erasing,
      onTap: () => setState(() {
        _erasing = true;
        _filling = false;
      }),
    );
  }
}
