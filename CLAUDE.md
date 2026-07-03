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

- `lib/main.dart` — the app UI and drawing logic:
  - `ColoringApp` — root `MaterialApp`
  - `ColoringPage` — stateful screen: canvas + toolbar (palette, eraser, brush slider,
    undo/redo, clear, save, and prev/next picture navigation)
  - `Stroke` — one drag stroke: `color`, `width`, `erase`, `points`
  - `ColoringTemplate` — a named picture with an optional outline drawer (null = blank)
  - `_Artboard` — per-picture `strokes` + `redo` lists (one per template)
  - `_CanvasPainter` — `CustomPainter` that draws background, outline, then strokes
  - top-level `_drawFish` / `_drawFlower` / `_drawHouse` / `_drawStar` — vector outlines
- `lib/save_image.dart` + `save_image_stub.dart` + `save_image_web.dart` — platform-
  conditional PNG save (`savePng`). Web triggers a browser download via `dart:html`;
  other platforms return a "not wired up" message. No packages.
- `test/widget_test.dart` — smoke test + undo/redo enable-state test
- Standard Flutter platform folders: `android/`, `ios/`, `web/`, `macos/`, etc.

## How drawing works

Each finger/mouse drag = one `Stroke` appended to the current picture's `_Artboard`.
`onPanStart` starts a stroke (clearing the redo list), `onPanUpdate` adds points.
`_CanvasPainter` paints in order: white background → template outline → a `saveLayer`
holding the user strokes. Eraser strokes use `BlendMode.clear` inside that layer, so
they punch back to the outline/background (a *real* eraser, not white paint).

- **Undo/redo** — per picture: undo moves the last stroke to `redo`, redo moves it back;
  a new stroke clears `redo`. **Clear** empties both (not itself undoable).
- **Multiple pictures** — each `ColoringTemplate` has its own `_Artboard`, so switching
  with the prev/next arrows preserves each picture's artwork.
- **Save** — a `RepaintBoundary` around the canvas is captured to a PNG and passed to
  `savePng`.

## Conventions

- Keep `flutter analyze` at **zero issues** before finishing a change.
- Prefer `const` constructors and `setState` for local UI state (no state-mgmt package
  needed at this scale).
- This is a learning repo — favor readable, well-commented code over cleverness.
- Commit messages: keep them short and clean. No `Co-Authored-By` trailers and no
  AI/Claude attribution — just a concise summary of the change.

## Ideas / next steps

Done: undo/redo, vector outline backgrounds, multiple pictures with navigation, and
web PNG save (real `BlendMode.clear` eraser). Possible follow-ups:

- Real device-gallery save on iOS/Android (would add `path_provider` + a gallery/share
  package and per-platform permission config — currently save is web-only)
- Bundle real PNG line-art as an alternative to the code-drawn vector templates
- Fill-a-region ("paint bucket") tool
- Custom color picker beyond the fixed palette
- Cache finished strokes into a `ui.Picture` so `shouldRepaint` doesn't redraw every
  stroke each frame as drawings grow large
