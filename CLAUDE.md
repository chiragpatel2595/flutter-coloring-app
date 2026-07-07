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
  (`drawFish` / `drawFlower` / `drawHouse` / `drawStar`) + helpers.
- `lib/canvas_painter.dart` — `CanvasPainter` (`CustomPainter`): background → outline →
  strokes in a `saveLayer` (real `BlendMode.clear` eraser).
- `lib/color_picker.dart` — `showColorPickerDialog`: a package-free HSV color picker
  (hue/saturation/brightness sliders + live preview).
- `lib/save_image.dart` + `save_image_stub.dart` + `save_image_web.dart` — platform-
  conditional PNG save (`savePng`). Web triggers a browser download via `dart:html`;
  other platforms return a "not wired up" message. No packages.
- `test/widget_test.dart` — smoke test + undo/redo enable-state test
- `test/interaction_test.dart` — navigation, per-picture strokes, clear-confirm,
  redo-cleared-on-new-stroke, multi-touch (two pointers)
- `test/render_test.dart` — pixel-level guard: captures the canvas and asserts each
  stroke actually repaints (catches `shouldRepaint`-style "nothing draws" regressions)
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
- **Colors** — 8 preset swatches plus a custom HSV picker (`color_picker.dart`); picked
  colors are remembered as extra swatches.
- **Undo/redo** — per picture: undo moves the last stroke to `redo`, redo moves it back;
  a new stroke clears `redo`. Keyboard shortcuts: Ctrl/Cmd+Z undo, add Shift (or Ctrl+Y)
  to redo. **Clear** empties both and can't be undone, so it asks for confirmation first.
- **Multiple pictures** — each `ColoringTemplate` has its own `_Artboard`, so switching
  with the prev/next arrows preserves each picture's artwork.
- **Save** — a `RepaintBoundary` around the canvas is captured to a PNG and passed to
  `savePng`. Disabled until something is drawn.
- **Accessibility** — swatches/eraser are `InkResponse` + `Tooltip` + `Semantics`
  (named, focusable, activatable). A brush-size preview dot sits by the slider.

## Conventions

- Keep `flutter analyze` at **zero issues** before finishing a change.
- Prefer `const` constructors and `setState` for local UI state (no state-mgmt package
  needed at this scale).
- This is a learning repo — favor readable, well-commented code over cleverness.
- Commit messages: keep them short and clean. No `Co-Authored-By` trailers and no
  AI/Claude attribution — just a concise summary of the change.

## Ideas / next steps

Done: undo/redo (+ keyboard shortcuts), vector outline backgrounds, multiple pictures
with navigation, web PNG save (real `BlendMode.clear` eraser), multi-touch drawing,
resize-safe normalized strokes, clear-confirmation, accessible swatches, brush preview,
and a pixel-level repaint test. Possible follow-ups:

- Real device-gallery save on iOS/Android (would add `path_provider` + a gallery/share
  package and per-platform permission config — currently save is web-only)
- Bundle real PNG line-art as an alternative to the code-drawn vector templates
- Fill-a-region ("paint bucket") tool
- Custom color picker beyond the fixed palette
- Cache finished strokes into a `ui.Picture` so `shouldRepaint` doesn't redraw every
  stroke each frame as drawings grow large
