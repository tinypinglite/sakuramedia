import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_system_stub.dart'
    if (dart.library.io) 'package:sakuramedia/features/image_search/presentation/image_search_file_system_io.dart'
    as file_system;

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
typedef ImageSearchSavePathPicker =
    Future<String?> Function(String suggestedFileName, String? dialogTitle);
typedef ImageSearchDirectoryProvider = Future<String?> Function();
typedef ImageSearchDocumentsDirectoryProvider = Future<String?> Function();
typedef ImageSearchEnvironmentLookup = String? Function(String name);
typedef ImageSearchDirectoryExists = bool Function(String path);

@visibleForTesting
ImageSearchFilePicker? debugImageSearchFilePicker;
@visibleForTesting
ImageSearchFilePicker? debugMobileImageSearchFilePicker;
@visibleForTesting
ImageSearchSavePathPicker? debugImageSearchSavePathPicker;
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
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'gif', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await file_system.readFileBytes(file.path!);
    }
    if (bytes == null || bytes.isEmpty) {
      throw const ImageSearchFilePickerException('无法读取所选图片，请换一张再试');
    }

    return ImageSearchPickedFile(
      bytes: bytes,
      fileName: file.name,
      mimeType: guessImageMimeType(file.name),
    );
  } on MissingPluginException catch (error, stackTrace) {
    debugPrint('Image search file picker plugin is unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw const ImageSearchFilePickerException('图片选择器尚未加载，请完整重启应用后再试');
  } on PlatformException catch (error, stackTrace) {
    debugPrint(
      'Image search file picker failed: ${error.message ?? error.code}',
    );
    debugPrintStack(stackTrace: stackTrace);
    throw ImageSearchFilePickerException(error.message ?? '打开图片选择器失败，请稍后再试');
  }
}

Future<ImageSearchPickedFile?> pickMobileImageSearchFile() async {
  final override = debugMobileImageSearchFilePicker;
  if (override != null) {
    return override();
  }
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return pickImageSearchFile();
  }

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      allowCompression: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await file_system.readFileBytes(file.path!);
    }
    if (bytes == null || bytes.isEmpty) {
      throw const ImageSearchFilePickerException('无法读取所选图片，请换一张再试');
    }
    return ImageSearchPickedFile(
      bytes: bytes,
      fileName: file.name,
      mimeType: guessImageMimeType(file.name),
    );
  } on MissingPluginException catch (error, stackTrace) {
    debugPrint('Mobile image file picker plugin is unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw const ImageSearchFilePickerException('图片选择器尚未加载，请完整重启应用后再试');
  } on PlatformException catch (error, stackTrace) {
    debugPrint(
      'Mobile image file picker failed: ${error.message ?? error.code}',
    );
    debugPrintStack(stackTrace: stackTrace);
    throw ImageSearchFilePickerException(error.message ?? '打开图片选择器失败，请稍后再试');
  }
}

@visibleForTesting
Future<String?> resolveImageSearchInitialDirectory() async {
  if (kIsWeb) {
    return null;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.android:
      return _resolveExistingDirectoryPath(
        await _resolveDownloadsDirectoryPath(),
        fallbackPaths: <String?>[
          if (defaultTargetPlatform == TargetPlatform.windows)
            _lookupEnvironmentPath('USERPROFILE'),
          if (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)
            _lookupEnvironmentPath('HOME'),
        ],
      );
    case TargetPlatform.iOS:
      return _resolveExistingDirectoryPath(
        await _resolveDownloadsDirectoryPath(),
        fallbackPaths: <String?>[await _resolveDocumentsDirectoryPath()],
      );
    case TargetPlatform.fuchsia:
      return null;
  }
}

Future<String?> pickImageSearchSavePath({
  required String suggestedFileName,
  String? dialogTitle,
}) async {
  final override = debugImageSearchSavePathPicker;
  if (override != null) {
    return override(suggestedFileName, dialogTitle);
  }

  try {
    final extension = guessImageFileExtension(suggestedFileName);
    return await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: <String>[extension],
    );
  } on MissingPluginException catch (error, stackTrace) {
    debugPrint('Image search save file picker plugin is unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw const ImageSearchFilePickerException('图片选择器尚未加载，请完整重启应用后再试');
  } on PlatformException catch (error, stackTrace) {
    debugPrint(
      'Image search save file picker failed: ${error.message ?? error.code}',
    );
    debugPrintStack(stackTrace: stackTrace);
    throw ImageSearchFilePickerException(error.message ?? '打开保存面板失败，请稍后再试');
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

String guessImageFileExtension(String fileName, {String fallback = 'webp'}) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'png';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'jpg';
  }
  if (lower.endsWith('.gif')) {
    return 'gif';
  }
  if (lower.endsWith('.webp')) {
    return 'webp';
  }
  return fallback;
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
