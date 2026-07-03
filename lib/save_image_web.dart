// Only compiled for the web target, where dart:html is available.
// dart:html is deprecated in favour of package:web, but it's dependency-free
// and perfectly fine for a small learning app, so we silence that lint here.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [pngBytes] as [filename] by clicking a
/// hidden anchor whose href is a base64 data URL.
Future<String> savePng(Uint8List pngBytes, String filename) async {
  final href = 'data:image/png;base64,${base64Encode(pngBytes)}';
  final anchor = html.AnchorElement(href: href)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  return 'Downloaded $filename.';
}
