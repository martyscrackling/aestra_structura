import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    as impl;

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  return impl.downloadBytes(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
