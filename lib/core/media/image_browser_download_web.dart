import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> saveImageBytesByBrowserDownload({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = web.Blob(<JSUint8Array>[bytes.toJS].toJS);
  final objectUrl = web.URL.createObjectURL(blob);
  try {
    final anchor =
        web.HTMLAnchorElement()
          ..href = objectUrl
          ..download = fileName;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  } finally {
    web.URL.revokeObjectURL(objectUrl);
  }
}
