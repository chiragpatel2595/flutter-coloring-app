# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A **Flutter coloring / finger-painting app** — a learning project to practice Flutter
(Dart, `CustomPainter`, gestures, state). It has no backend, no auth, and no network
calls; everything runs on-device.

## Tech

- **Flutter** 3.44.x (stable), **Dart** 3.12.x
- Targets: web (primary during dev), iOS, Android, macOS
- No third-party packages yet — pure Flutter SDK

## Run / build

Flutter lives at `/opt/homebrew/bin` (installed via Homebrew). Prefix commands with
`export PATH="/opt/homebrew/bin:$PATH"` if `flutter` isn't found.

```bash
flutter run -d chrome     # run in the browser (fastest dev loop, no Xcode/Android needed)
flutter analyze           # static analysis — keep this clean
flutter test              # run widget tests
flutter build apk         # Android build (requires Android Studio / Android SDK)
```

Press `r` in a running session for hot-reload, `R` for hot-restart.

## Code layout

The app is split into small, focused files (was one big `main.dart`):

- `lib/main.dart` — entry point only: `main()` + `ColoringApp` (root `MaterialApp`).
- `lib/coloring_page.dart` — `ColoringPage` stateful screen: the canvas + toolbar
  (palette, custom-color picker, eraser, brush slider + preview, undo/redo, clear,
  save, prev/next navigation) and all pointer/gesture + action logic.
- `lib/models.dart` — plain data: `Stroke` (color, width, erase, normalized `points`),
  `ColoringTemplate` (name + optional `OutlineDrawer`), `Artboard` (per-picture
  `strokes` + `redo`).
- `lib/templates.dart` — the `kTemplates` list and vector outline drawers
  (fish / flower / house / star / heart / sun / tree / car) + helpers, plus
  `kActiveTemplate`: the one picture shown while navigation is switched off.
- `lib/canvas_painter.dart` — `CanvasPainter` (`CustomPainter`): background → outline →
  strokes in a `saveLayer` (real `BlendMode.clear` eraser).
- `lib/color_picker.dart` — `showColorPickerDialog`: a package-free HSV color picker
  (hue/saturation/brightness sliders + live preview).
- `lib/kid_palette.dart` — the whole color scheme in one file: the chrome tokens
  (background / toolbar / primary / secondary / success / error / ink / outline), the
  16 `kCrayonColors`, and `kBrushSizes`, the four named brush presets that replaced the
  px slider.
- `lib/crayon.dart` — `Crayon`: one drawable crayon (waxy tip, body, paper wrapper +
  stripes) that lifts and tilts when selected. The app's signature element.
- `lib/flood_fill.dart` — pure `floodFill()` over a raw RGBA buffer (no engine), so the
  paint-bucket algorithm is unit-testable on its own. Includes the soft-edge growth
  passes that stop fills leaving a halo around anti-aliased strokes.
- `lib/save_image.dart` + `save_image_stub.dart` + `save_image_web.dart` — platform-
  conditional PNG save (`savePng`). Web triggers a browser download via `dart:html`;
  other platforms return a "not wired up" message. No packages.
- `test/widget_test.dart` — smoke test + undo/redo enable-state test
- `test/interaction_test.dart` — single-page (no nav arrows), brush-size selection,
  clear-confirm, redo-cleared-on-new-stroke, multi-touch (two pointers)
- `test/render_test.dart` — pixel-level guard: captures the canvas and asserts each
  stroke actually repaints (catches `shouldRepaint`-style "nothing draws" regressions)
- `test/animation_test.dart` — drives the clock by hand to check the finish-stroke
  "pop" swells mid-animation, settles back, and stops (and that erasing doesn't pop)
- `test/helpers.dart` — shared `pressRedo()` (Ctrl+Shift+Z), since redo has no button
- Standard Flutter platform folders: `android/`, `ios/`, `web/`, `macos/`, etc.

## How drawing works

Input comes from a raw `Listener` (not `GestureDetector`), so each pointer is tracked
separately in `_active` (a `Map<int, Stroke>` keyed by pointer id) — that's what makes
**multi-touch** work: two fingers get two independent strokes. Pointer-down starts a
stroke (clearing the redo list), pointer-move extends it, pointer-up/cancel ends it.
A `LayoutBuilder` supplies the live canvas size so points are stored **normalized**
(0..1 fractions of the canvas), and scaled back to pixels in `_CanvasPainter`. This keeps
strokes aligned with the outline when the window resizes instead of drifting.

`_CanvasPainter` paints in order: white background → template outline → a `saveLayer`
holding the user strokes. Eraser strokes use `BlendMode.clear` inside that layer, so
they punch back to the outline/background (a *real* eraser, not white paint).

- **Brushes** — `BrushType` (pen / marker / highlighter / spray) selected in the toolbar.
  Pen is a solid line; marker and highlighter are semi-transparent flat lines; spray is
  an airbrush whose scattered dots are *baked* at draw time (in `_pointsAt`) so it stays
  stable across repaints. `CanvasPainter._paintFor` maps each type to its `Paint`.
- **Colors** — 16 crayons (`kCrayonColors`) in spectrum order, scrolling on the plain
  white toolbar. There's no drawn tray: with that many crayons the row is already the
  most colorful thing on screen. Picked custom colors are remembered as extra crayons.
  The chosen crayon rises and tilts (`Curves.elasticOut`) instead of getting a selection
  ring — position and angle read faster than a border. Each crayon reserves
  `Crayon.liftRoom` above itself so the rise isn't clipped by the scroll view.
  `Crayon` shades each wrapper from the crayon's own color; the light/dark cutoff sits
  at L<0.30, not 0.5, or vivid mid-darks (teal, brown) get washed-out pale bodies.
- **UI color** — the chrome is deliberately plainer than the crayons. Surfaces are
  white on an off-white background separated by hairlines; `primary` marks the selected
  tool (the only solid accent), `secondary` the "mix your own color" button, and
  `success`/`error` the save and destructive paths. The "add a color" button lives with
  the tools, not in the crayon row — sixteen crayons scroll well past the screen and
  would bury it.
- **Brush size** — four preset dots (`kBrushSizes`), not a slider. The dot shows the real
  brush color at a comparable size, so it doubles as the preview and needs no "12px"
  label — a child picks by looking, not by reading.
- **Paint bucket** — a picture is an ordered list of `Layer`s (`Stroke` | `Fill`), so
  fills and strokes share one z-order and one undo stack. Tapping with the bucket
  rasterizes the canvas, runs the pure `floodFill()`, bakes the result to a `Fill`
  (`ui.Image`), and adds it as a layer. `Fill` images are disposed when discarded
  (clear, or a redo pile dropped by a new action).
  **Soft edges**: strokes are anti-aliased, so their edges are a 1–2px band that's too
  far from white to pass the fill tolerance but too pale to read as stroke — a plain
  flood fill leaves a pale halo tracing every stroke (made worse by the fill being
  captured at `pixelRatio: 1` and stretched back up). `floodFill` therefore grows
  `edgePasses` extra rings using a looser `edgeTol`. The growth test compares against
  the *seed* color, not the neighbour, so it can never walk through a barrier no matter
  how many passes run — there's a test pinning exactly that.
- **Stroke "pop"** — lifting your finger briefly swells the stroke you just drew, then
  settles it back. An `AnimationController` on `_ColoringPageState` (created in
  `initState`, released in `dispose`) drives a 0→1 value; an `AnimatedBuilder` around
  the `CustomPaint` rebuilds only the canvas each frame, and `CanvasPainter._popScale`
  turns that value into a width multiplier — a damped wobble (`sin` over 1.5 turns times
  `(1 - t)`) so the line springs like rubber and settles at exactly 1.0. It's purely
  visual — the stored `Stroke` is untouched, so undo/redo and save are unaffected.
  Eraser strokes don't pop.
- **Undo/redo** — per picture: undo moves the last stroke to `redo`, redo moves it back;
  a new stroke clears `redo`. Keyboard shortcuts: Ctrl/Cmd+Z undo, add Shift (or Ctrl+Y)
  to redo. **There is no redo button** — it needs a history-stack mental model a small
  child doesn't have, and sat disabled most of the time; the keyboard path (and so the
  only way to test redo, see `test/helpers.dart`) remains for grown-ups. **Clear** empties
  both and can't be undone, so it asks for confirmation first.
- **One picture (for now)** — page navigation is switched off. `kActiveTemplate`
  (`templates.dart`) picks the single template shown, and `_ColoringPageState` holds one
  `Artboard` instead of a list. The other eight outline drawers are still in
  `kTemplates`, untouched, so restoring the pager is wiring, not rewriting.
  When it comes back, the arrows must **not** sit at the ends of the crayon tray —
  arrows either side of a horizontally scrolling row read as "scroll this row", so they
  looked like crayon controls. Put them beside the picture's *name*.
- **Save** — a `RepaintBoundary` around the canvas is captured to a PNG and passed to
  `savePng`. Disabled until something is drawn.
- **Accessibility** — crayons, sizes, brushes and tools are all `InkResponse` +
  `Tooltip` + `Semantics` (named, focusable, activatable, and `selected:` set so screen
  readers announce the current choice — which is also how the size test asserts state).
  Touch targets are 52px+ throughout, since small children aim coarsely.

## Conventions

- Keep `flutter analyze` at **zero issues** before finishing a change.
- Prefer `const` constructors and `setState` for local UI state (no state-mgmt package
  needed at this scale).
- This is a learning repo — favor readable, well-commented code over cleverness.
- Commit messages: keep them short and clean. No `Co-Authored-By` trailers and no
  AI/Claude attribution — just a concise summary of the change.

## Ideas / next steps

Done: undo/redo (+ keyboard shortcuts), vector outline backgrounds (9 drawers, one
shown), web PNG save (real `BlendMode.clear` eraser), multi-touch drawing,
resize-safe normalized strokes, clear-confirmation, accessible swatches, brush preview,
a custom HSV color picker, brush types (pen/marker/highlighter/spray), a paint-bucket
flood fill (layer model + pure algorithm), and a modular file layout with a pixel-level
repaint test. Possible follow-ups:

- Real device-gallery save on iOS/Android (would add `path_provider` + a gallery/share
  package and per-platform permission config — currently save is web-only)
- Bundle real PNG line-art as an alternative to the code-drawn vector templates
- Run `floodFill` in an isolate if fills on large canvases ever feel janky
- Cache finished layers into a `ui.Picture` so `shouldRepaint` doesn't redraw every
  layer each frame as drawings grow large
