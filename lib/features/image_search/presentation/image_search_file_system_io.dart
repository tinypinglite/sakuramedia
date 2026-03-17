import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Uint8List?> readFileBytes(String path) async {
  return File(path).readAsBytes();
}

Future<String?> resolveDownloadsDirectoryPath() async {
  try {
    return (await getDownloadsDirectory())?.path;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on UnsupportedError {
    return null;
  }
}

Future<String?> resolveDocumentsDirectoryPath() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on UnsupportedError {
    return null;
  }
}

String? readEnvironment(String name) {
  return Platform.environment[name];
}

bool directoryExists(String path) {
  return Directory(path).existsSync();
}
