import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final outPath = p.join(dir.path, filename);
    final file = File(outPath);
    await file.writeAsBytes(bytes, flush: true);
    return;
  }

  final dir = await getTemporaryDirectory();
  final outPath = p.join(dir.path, filename);
  final file = File(outPath);
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile(outPath, mimeType: mimeType, name: filename),
      ],
    ),
  );
}
