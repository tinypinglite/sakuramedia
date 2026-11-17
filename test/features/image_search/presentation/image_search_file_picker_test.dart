import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingFilePicker recordingFilePicker;
  late FilePickerPlatform originalFilePicker;

  setUp(() {
    recordingFilePicker = _RecordingFilePicker();
    originalFilePicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = recordingFilePicker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalFilePicker;
    debugDefaultTargetPlatformOverride = null;
    debugImageSearchDownloadsDirectoryProvider = null;
    debugImageSearchDocumentsDirectoryProvider = null;
    debugImageSearchEnvironmentLookup = null;
    debugImageSearchDirectoryExists = null;
    debugMobileImageSearchFilePicker = null;
  });

  test('pickMobileImageSearchFile reads selected file bytes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    recordingFilePicker.selectedFile = _SelectedFile(
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    final result = await pickMobileImageSearchFile(l10n: AppLocalizationsZh());

    expect(result!.bytes, [1, 2, 3]);
    expect(result.fileName, 'photo.png');
    expect(result.mimeType, 'image/png');
  });

  test('pickMobileImageSearchFile rejects empty files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    recordingFilePicker.selectedFile = _SelectedFile(bytes: Uint8List(0));

    await expectLater(
      pickMobileImageSearchFile(l10n: AppLocalizationsZh()),
      throwsA(isA<ImageSearchFilePickerException>()),
    );
  });

  test('pickMobileImageSearchFile reports unreadable files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    recordingFilePicker.selectedFile = _SelectedFile();

    await expectLater(
      pickMobileImageSearchFile(l10n: AppLocalizationsZh()),
      throwsA(
        isA<ImageSearchFilePickerException>().having(
          (error) => error.message,
          'message',
          AppLocalizationsZh().imageSearchPickUnreadable,
        ),
      ),
    );
  });

  test('pickImageSearchFile uses downloads directory on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugImageSearchDownloadsDirectoryProvider = () async =>
        '/Users/test/Downloads';
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile(l10n: AppLocalizationsZh());

    expect(
      recordingFilePicker.pickFileInitialDirectory,
      '/Users/test/Downloads',
    );
  });

  test('pickImageSearchFile uses downloads directory on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    debugImageSearchDownloadsDirectoryProvider = () async =>
        '/storage/emulated/0/Download';
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile(l10n: AppLocalizationsZh());

    expect(
      recordingFilePicker.pickFileInitialDirectory,
      '/storage/emulated/0/Download',
    );
  });

  test(
    'pickImageSearchFile falls back to documents directory on iOS',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      debugImageSearchDownloadsDirectoryProvider = () async => null;
      debugImageSearchDocumentsDirectoryProvider = () async =>
          '/var/mobile/Documents';
      debugImageSearchDirectoryExists = (_) => true;

      await pickImageSearchFile(l10n: AppLocalizationsZh());

      expect(
        recordingFilePicker.pickFileInitialDirectory,
        '/var/mobile/Documents',
      );
    },
  );

  test('pickImageSearchFile falls back to USERPROFILE on Windows', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    debugImageSearchDownloadsDirectoryProvider = () async => null;
    debugImageSearchEnvironmentLookup = (name) =>
        name == 'USERPROFILE' ? r'C:\Users\tester' : null;
    debugImageSearchDirectoryExists = (_) => true;

    await pickImageSearchFile(l10n: AppLocalizationsZh());

    expect(recordingFilePicker.pickFileInitialDirectory, r'C:\Users\tester');
  });

  test(
    'pickImageSearchFile leaves initial directory empty on unsupported platforms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      await pickImageSearchFile(l10n: AppLocalizationsZh());

      expect(recordingFilePicker.pickFileInitialDirectory, isNull);
    },
  );

  test('pickImageSearchFile allows heic and heif files on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugImageSearchDownloadsDirectoryProvider = () async => null;
    debugImageSearchEnvironmentLookup = (_) => null;

    await pickImageSearchFile(l10n: AppLocalizationsZh());

    expect(
      recordingFilePicker.pickFileAllowedExtensions,
      containsAll(<String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif']),
    );
  });

  test('guessImageMimeType maps heic and heif files', () {
    expect(guessImageMimeType('IMG_0001.HEIC'), 'image/heic');
    expect(guessImageMimeType('photo.heif'), 'image/heif');
  });

  test('pickMobileImageSearchFile uses debug override', () async {
    debugMobileImageSearchFilePicker = () async => ImageSearchPickedFile(
      bytes: Uint8List.fromList(const <int>[7, 8, 9]),
      fileName: 'mobile.png',
      mimeType: 'image/png',
    );

    final picked = await pickMobileImageSearchFile(l10n: AppLocalizationsZh());

    expect(picked, isNotNull);
    expect(picked!.fileName, 'mobile.png');
    expect(picked.mimeType, 'image/png');
    expect(picked.bytes, Uint8List.fromList(const <int>[7, 8, 9]));
  });

  test(
    'pickMobileImageSearchFile returns null when picker is cancelled',
    () async {
      debugMobileImageSearchFilePicker = () async => null;

      final picked = await pickMobileImageSearchFile(
        l10n: AppLocalizationsZh(),
      );

      expect(picked, isNull);
    },
  );

  test(
    'pickMobileImageSearchFile uses image file type picker on Android',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await pickMobileImageSearchFile(l10n: AppLocalizationsZh());

      expect(recordingFilePicker.pickFileType, FileType.image);
      expect(recordingFilePicker.pickFileInitialDirectory, isNull);
    },
  );

  test('pickMobileImageSearchFile disables compression on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await pickMobileImageSearchFile(l10n: AppLocalizationsZh());

    expect(recordingFilePicker.pickFileCompressionQuality, 0);
  });
}

class _RecordingFilePicker extends FilePickerPlatform {
  String? pickFileInitialDirectory;
  FileType? pickFileType;
  int? pickFileCompressionQuality;
  List<String>? pickFileAllowedExtensions;
  PlatformFile? selectedFile;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickFileInitialDirectory = initialDirectory;
    pickFileType = type;
    pickFileCompressionQuality = compressionQuality;
    pickFileAllowedExtensions = allowedExtensions;
    return selectedFile;
  }
}

final class _SelectedFile extends PlatformFile {
  _SelectedFile({this.bytes});

  final Uint8List? bytes;

  @override
  String get name => 'photo.png';

  @override
  Future<Uint8List> readAsBytes() async {
    if (bytes == null) throw StateError('Cannot read selected file');
    return bytes!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
