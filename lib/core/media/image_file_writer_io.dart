import 'dart:io';
import 'dart:typed_data';

Future<void> writeBytesToFile(String path, Uint8List bytes) {
  return File(path).writeAsBytes(bytes, flush: true);
}
