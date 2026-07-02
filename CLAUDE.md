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

- `lib/main.dart` — the entire app (single file):
  - `ColoringApp` — root `MaterialApp`
  - `ColoringPage` — stateful screen: canvas + toolbar (palette, eraser, brush slider, undo, clear)
  - `Stroke` — one drag stroke: `color`, `width`, `points`
  - `_CanvasPainter` — `CustomPainter` that draws all strokes each frame
- `test/widget_test.dart` — smoke test that the page renders
- Standard Flutter platform folders: `android/`, `ios/`, `web/`, `macos/`, etc.

## How drawing works

Each finger/mouse drag = one `Stroke` appended to `_strokes`. `onPanStart` starts a
stroke, `onPanUpdate` adds points, and `_CanvasPainter` repaints the full list. Undo =
`removeLast()`, clear = `clear()`, eraser = a stroke painted white.

## Conventions

- Keep `flutter analyze` at **zero issues** before finishing a change.
- Prefer `const` constructors and `setState` for local UI state (no state-mgmt package
  needed at this scale).
- This is a learning repo — favor readable, well-commented code over cleverness.

## Ideas / next steps

- Undo **redo** stack
- Load a coloring-book outline PNG as the canvas background
- Save artwork to gallery (`image` + `path_provider` packages)
- Multiple pages/pictures with navigation
