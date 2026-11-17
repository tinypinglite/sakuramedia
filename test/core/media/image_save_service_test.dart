import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  test(
    'desktop save passes image bytes and MIME type to file picker',
    () async {
      final original = FilePickerPlatform.instance;
      final picker = _SaveFilePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      final service = ImageSaveService(
        fetchBytes: (_) async => Uint8List.fromList([1, 2, 3]),
        resolvePlatform: () => ImageSavePlatform.desktop,
      );

      final result = await service.saveImageFromUrl(
        imageUrl: '/photo.jpg',
        dialogTitle: '保存图片',
        l10n: zh,
      );

      expect(result.status, ImageSaveStatus.success);
      expect(result.savedPath, Uri.file('/tmp/photo.jpg').toFilePath());
      expect(picker.fileName, 'photo.jpg');
      expect(picker.bytes, [1, 2, 3]);
      expect(picker.mimeType, 'image/jpeg');
      expect(picker.dialogTitle, '保存图片');
    },
  );

  test('image save service downloads bytes and writes selected file', () async {
    String? requestedUrl;
    String? requestedName;
    Uint8List? writtenBytes;

    final service = ImageSaveService(
      fetchBytes: (imageUrl) async {
        requestedUrl = imageUrl;
        return Uint8List.fromList(const <int>[1, 2, 3]);
      },
      saveToDesktop:
          ({
            required suggestedFileName,
            required bytes,
            String? dialogTitle,
          }) async {
            requestedName = suggestedFileName;
            writtenBytes = bytes;
            return '/tmp/result.webp';
          },
      resolvePlatform: () => ImageSavePlatform.desktop,
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
      l10n: zh,
    );

    expect(result.status, ImageSaveStatus.success);
    expect(requestedUrl, '/images/thumb.webp');
    expect(requestedName, 'thumb.webp');
    expect(result.savedPath, '/tmp/result.webp');
    expect(writtenBytes, Uint8List.fromList(const <int>[1, 2, 3]));
  });

  test(
    'image save service returns cancelled when user closes save dialog',
    () async {
      final service = ImageSaveService(
        fetchBytes: (_) async => Uint8List.fromList(const <int>[1, 2, 3]),
        saveToDesktop:
            ({
              required suggestedFileName,
              required bytes,
              String? dialogTitle,
            }) async => null,
        resolvePlatform: () => ImageSavePlatform.desktop,
      );

      final result = await service.saveImageFromUrl(
        imageUrl: '/images/thumb.webp',
        l10n: zh,
      );

      expect(result.status, ImageSaveStatus.cancelled);
    },
  );

  test('image save service reports download failures', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => throw Exception('boom'),
      saveToDesktop:
          ({
            required suggestedFileName,
            required bytes,
            String? dialogTitle,
          }) async => '/tmp/result.webp',
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      l10n: zh,
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, zh.coreImageSaveFailed);
  });

  test('image save service reports write failures', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[1, 2, 3]),
      saveToDesktop:
          ({
            required suggestedFileName,
            required bytes,
            String? dialogTitle,
          }) async => throw Exception('boom'),
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      l10n: zh,
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, zh.coreImageSaveFailed);
  });

  test('image save service saves to gallery on mobile', () async {
    var permissionRequested = false;
    Uint8List? savedBytes;
    String? savedFileName;

    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[4, 5, 6]),
      resolvePlatform: () => ImageSavePlatform.mobile,
      requestGalleryPermission: () async {
        permissionRequested = true;
        return true;
      },
      saveToGallery: ({required bytes, required fileName}) async {
        savedBytes = bytes;
        savedFileName = fileName;
        return true;
      },
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
      l10n: zh,
    );

    expect(permissionRequested, isTrue);
    expect(savedBytes, Uint8List.fromList(const <int>[4, 5, 6]));
    expect(savedFileName, 'thumb.webp');
    expect(result.status, ImageSaveStatus.success);
    expect(result.message, zh.coreImageSaveToGallery);
  });

  test(
    'image save service returns error when gallery permission is denied',
    () async {
      final service = ImageSaveService(
        fetchBytes: (_) async => Uint8List.fromList(const <int>[4, 5, 6]),
        resolvePlatform: () => ImageSavePlatform.mobile,
        requestGalleryPermission: () async => false,
        saveToGallery: ({required bytes, required fileName}) async => true,
      );

      final result = await service.saveImageFromUrl(
        imageUrl: '/images/thumb.webp',
        fileName: 'thumb.webp',
        l10n: zh,
      );

      expect(result.status, ImageSaveStatus.failed);
      expect(result.message, zh.coreImageSavePermissionDenied);
    },
  );

  test('image save service reports gallery save failures', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[4, 5, 6]),
      resolvePlatform: () => ImageSavePlatform.mobile,
      requestGalleryPermission: () async => true,
      saveToGallery: ({required bytes, required fileName}) async => false,
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
      l10n: zh,
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, zh.coreImageSaveFailed);
  });

  test('image save service uses the wording of the given language', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[4, 5, 6]),
      resolvePlatform: () => ImageSavePlatform.mobile,
      requestGalleryPermission: () async => true,
      saveToGallery: ({required bytes, required fileName}) async => true,
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
      l10n: en,
    );

    expect(result.status, ImageSaveStatus.success);
    expect(result.message, en.coreImageSaveToGallery);
  });
}

class _SaveFilePicker extends FilePickerPlatform {
  String? fileName;
  Uint8List? bytes;
  String? mimeType;
  String? dialogTitle;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    this.mimeType = mimeType;
    this.dialogTitle = dialogTitle;
    return Uri.file('/tmp/photo.jpg');
  }
}
