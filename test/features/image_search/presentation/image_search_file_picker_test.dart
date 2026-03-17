import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingFilePicker recordingFilePicker;

  setUp(() {
    recordingFilePicker = _RecordingFilePicker();
    FilePicker.platform = recordingFilePicker;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    debugImageSearchDownloadsDirectoryProvider = null;
    debugImageSearchDocumentsDirectoryProvider = null;
    debugImageSearchEnvironmentLookup = null;
    debugImageSearchDirectoryExists = null;
    debugMobileImageSearchFilePicker = null;
  });

  test('pickImageSearchFile uses downloads directory on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugImageSearchDownloadsDirectoryProvider =
        () async => '/Users/test/Downloads';
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile();

    expect(
      recordingFilePicker.pickFilesInitialDirectory,
      '/Users/test/Downloads',
    );
  });

  test('pickImageSearchFile uses downloads directory on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    debugImageSearchDownloadsDirectoryProvider =
        () async => '/storage/emulated/0/Download';
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile();

    expect(
      recordingFilePicker.pickFilesInitialDirectory,
      '/storage/emulated/0/Download',
    );
  });

  test(
    'pickImageSearchFile falls back to documents directory on iOS',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      debugImageSearchDownloadsDirectoryProvider = () async => null;
      debugImageSearchDocumentsDirectoryProvider =
          () async => '/var/mobile/Documents';
      debugImageSearchDirectoryExists = (_) => true;

      await pickImageSearchFile();

      expect(
        recordingFilePicker.pickFilesInitialDirectory,
        '/var/mobile/Documents',
      );
    },
  );

  test('pickImageSearchFile falls back to USERPROFILE on Windows', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    debugImageSearchDownloadsDirectoryProvider = () async => null;
    debugImageSearchEnvironmentLookup =
        (name) => name == 'USERPROFILE' ? r'C:\Users\tester' : null;
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile();

    expect(recordingFilePicker.pickFilesInitialDirectory, r'C:\Users\tester');
  });

  test(
    'pickImageSearchFile ignores missing downloads directory on Linux',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      debugImageSearchDownloadsDirectoryProvider =
          () async => '/home/test/Downloads';
      debugImageSearchEnvironmentLookup =
          (name) => name == 'HOME' ? '/home/test' : null;
      debugImageSearchDirectoryExists = (path) => path == '/home/test';

      await pickImageSearchFile();

      expect(recordingFilePicker.pickFilesInitialDirectory, '/home/test');
    },
  );

  test(
    'pickImageSearchFile leaves initial directory empty on unsupported platforms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      await pickImageSearchFile();

      expect(recordingFilePicker.pickFilesInitialDirectory, isNull);
    },
  );

  test('pickMobileImageSearchFile uses debug override', () async {
    debugMobileImageSearchFilePicker =
        () async => ImageSearchPickedFile(
          bytes: Uint8List.fromList(const <int>[7, 8, 9]),
          fileName: 'mobile.png',
          mimeType: 'image/png',
        );

    final picked = await pickMobileImageSearchFile();

    expect(picked, isNotNull);
    expect(picked!.fileName, 'mobile.png');
    expect(picked.mimeType, 'image/png');
    expect(picked.bytes, Uint8List.fromList(const <int>[7, 8, 9]));
  });

  test(
    'pickMobileImageSearchFile returns null when picker is cancelled',
    () async {
      debugMobileImageSearchFilePicker = () async => null;

      final picked = await pickMobileImageSearchFile();

      expect(picked, isNull);
    },
  );

  test(
    'pickMobileImageSearchFile uses image file type picker on Android',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await pickMobileImageSearchFile();

      expect(recordingFilePicker.pickFilesType, FileType.image);
      expect(recordingFilePicker.pickFilesInitialDirectory, isNull);
    },
  );

  test('pickMobileImageSearchFile disables compression on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await pickMobileImageSearchFile();

    expect(recordingFilePicker.pickFilesAllowCompression, isFalse);
  });
}

class _RecordingFilePicker extends FilePicker {
  String? pickFilesInitialDirectory;
  FileType? pickFilesType;
  bool? pickFilesAllowCompression;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus p1)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    pickFilesInitialDirectory = initialDirectory;
    pickFilesType = type;
    pickFilesAllowCompression = allowCompression;
    return null;
  }

  @override
  Future<bool?> clearTemporaryFiles() async => true;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => null;
}
