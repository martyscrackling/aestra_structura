import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError('File download is only supported on Flutter Web');
}
