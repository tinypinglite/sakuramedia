import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_system_io.dart'
    as file_system;
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';

export 'package:sakuramedia/core/format/image_file_extension.dart'
    show guessImageFileExtension;

class ImageSearchPickedFile {
  const ImageSearchPickedFile({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? mimeType;
}

typedef ImageSearchFilePicker = Future<ImageSearchPickedFile?> Function();
typedef ImageSearchDirectoryProvider = Future<String?> Function();
typedef ImageSearchDocumentsDirectoryProvider = Future<String?> Function();
typedef ImageSearchEnvironmentLookup = String? Function(String name);
typedef ImageSearchDirectoryExists = bool Function(String path);

@visibleForTesting
ImageSearchFilePicker? debugImageSearchFilePicker;
@visibleForTesting
ImageSearchFilePicker? debugMobileImageSearchFilePicker;
@visibleForTesting
ImageSearchDirectoryProvider? debugImageSearchDownloadsDirectoryProvider;
@visibleForTesting
ImageSearchDocumentsDirectoryProvider?
debugImageSearchDocumentsDirectoryProvider;
@visibleForTesting
ImageSearchEnvironmentLookup? debugImageSearchEnvironmentLookup;
@visibleForTesting
ImageSearchDirectoryExists? debugImageSearchDirectoryExists;

class ImageSearchFilePickerException implements Exception {
  const ImageSearchFilePickerException(this.message);

  final String message;
}

Future<ImageSearchPickedFile?> pickImageSearchFile() async {
  final override = debugImageSearchFilePicker;
  if (override != null) {
    return override();
  }

  try {
    final initialDirectory = await resolveImageSearchInitialDirectory();
    final picked = await pickFileWithBytes(
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
      initialDirectory: initialDirectory,
      readPathFallback: file_system.readFileBytes,
      unreadableMessage: '无法读取所选图片，请换一张再试',
      pickerUnavailableMessage: '图片选择器尚未加载，请完整重启应用后再试',
      openFailureMessage: '打开图片选择器失败，请稍后再试',
    );
    if (picked == null) {
      return null;
    }
    return ImageSearchPickedFile(
      bytes: picked.bytes,
      fileName: picked.fileName,
      mimeType: guessImageMimeType(picked.fileName),
    );
  } on FilePickerWithBytesException catch (error) {
    throw ImageSearchFilePickerException(error.message);
  }
}

Future<ImageSearchPickedFile?> pickMobileImageSearchFile() async {
  final override = debugMobileImageSearchFilePicker;
  if (override != null) {
    return override();
  }
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return pickImageSearchFile();
  }

  try {
    final picked = await pickFileWithBytes(
      type: FileType.image,
      readPathFallback: file_system.readFileBytes,
      unreadableMessage: '无法读取所选图片，请换一张再试',
      pickerUnavailableMessage: '图片选择器尚未加载，请完整重启应用后再试',
      openFailureMessage: '打开图片选择器失败，请稍后再试',
    );
    if (picked == null) {
      return null;
    }
    return ImageSearchPickedFile(
      bytes: picked.bytes,
      fileName: picked.fileName,
      mimeType: guessImageMimeType(picked.fileName),
    );
  } on FilePickerWithBytesException catch (error) {
    throw ImageSearchFilePickerException(error.message);
  }
}

@visibleForTesting
Future<String?> resolveImageSearchInitialDirectory() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.android:
      return _resolveExistingDirectoryPath(
        await _resolveDownloadsDirectoryPath(),
        fallbackPaths: <String?>[
          if (defaultTargetPlatform == TargetPlatform.windows)
            _lookupEnvironmentPath('USERPROFILE'),
          if (defaultTargetPlatform == TargetPlatform.macOS)
            _lookupEnvironmentPath('HOME'),
        ],
      );
    case TargetPlatform.iOS:
      return _resolveExistingDirectoryPath(
        await _resolveDownloadsDirectoryPath(),
        fallbackPaths: <String?>[await _resolveDocumentsDirectoryPath()],
      );
    default:
      return null;
  }
}

String? guessImageMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  return null;
}

Future<String?> _resolveDownloadsDirectoryPath() async {
  final provider =
      debugImageSearchDownloadsDirectoryProvider ??
      file_system.resolveDownloadsDirectoryPath;
  return provider();
}

Future<String?> _resolveDocumentsDirectoryPath() async {
  final provider =
      debugImageSearchDocumentsDirectoryProvider ??
      file_system.resolveDocumentsDirectoryPath;
  return provider();
}

Future<String?> _resolveExistingDirectoryPath(
  String? primaryPath, {
  Iterable<String?> fallbackPaths = const <String?>[],
}) async {
  final candidates = <String?>[primaryPath, ...fallbackPaths];
  for (final candidate in candidates) {
    final normalized = candidate?.trim();
    if (normalized == null || normalized.isEmpty) {
      continue;
    }
    if (_directoryExists(normalized)) {
      return normalized;
    }
  }
  return null;
}

String? _lookupEnvironmentPath(String name) {
  final path = (debugImageSearchEnvironmentLookup ?? _readEnvironment)(name);
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _readEnvironment(String name) => file_system.readEnvironment(name);

bool _directoryExists(String path) {
  final override = debugImageSearchDirectoryExists;
  if (override != null) {
    return override(path);
  }
  return file_system.directoryExists(path);
}
