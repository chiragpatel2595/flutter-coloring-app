import 'dart:typed_data';

/// Fallback used on non-web platforms. Saving to the device gallery needs
/// extra packages (e.g. path_provider + image_gallery_saver), which this
/// pure-SDK learning app hasn't added yet — so we just explain that.
Future<String> savePng(Uint8List pngBytes, String filename) async {
  return 'Saving is only wired up for web in this build.';
}
