import 'dart:typed_data';

// Conditional import: use the web implementation when dart:html is available
// (i.e. when compiled for the web), otherwise fall back to the stub.
import 'save_image_stub.dart'
    if (dart.library.html) 'save_image_web.dart'
    as platform;

/// Saves [pngBytes] under [filename] using whatever mechanism the current
/// platform supports, returning a short status message to show the user.
///
/// On web this triggers a browser download. On other platforms (which this
/// learning app doesn't wire up for saving yet) it returns an explanatory
/// note instead of crashing.
Future<String> savePng(Uint8List pngBytes, String filename) =>
    platform.savePng(pngBytes, filename);
