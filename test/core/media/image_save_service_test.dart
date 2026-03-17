import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image save service downloads bytes and writes selected file', () async {
    String? requestedUrl;
    String? requestedName;
    String? writtenPath;
    Uint8List? writtenBytes;

    final service = ImageSaveService(
      fetchBytes: (imageUrl) async {
        requestedUrl = imageUrl;
        return Uint8List.fromList(const <int>[1, 2, 3]);
      },
      pickSavePath: ({required suggestedFileName, String? dialogTitle}) async {
        requestedName = suggestedFileName;
        return '/tmp/result.webp';
      },
      writeFile: (path, bytes) async {
        writtenPath = path;
        writtenBytes = bytes;
      },
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
    );

    expect(result.status, ImageSaveStatus.success);
    expect(requestedUrl, '/images/thumb.webp');
    expect(requestedName, 'thumb.webp');
    expect(writtenPath, '/tmp/result.webp');
    expect(writtenBytes, Uint8List.fromList(const <int>[1, 2, 3]));
  });

  test(
    'image save service returns cancelled when user closes save dialog',
    () async {
      final service = ImageSaveService(
        fetchBytes: (_) async => Uint8List.fromList(const <int>[1, 2, 3]),
        pickSavePath:
            ({required suggestedFileName, String? dialogTitle}) async => null,
        writeFile: (_, __) async {},
      );

      final result = await service.saveImageFromUrl(
        imageUrl: '/images/thumb.webp',
      );

      expect(result.status, ImageSaveStatus.cancelled);
    },
  );

  test('image save service reports download failures', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => throw Exception('boom'),
      pickSavePath:
          ({required suggestedFileName, String? dialogTitle}) async =>
              '/tmp/result.webp',
      writeFile: (_, __) async {},
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, '保存失败，请稍后重试');
  });

  test('image save service reports write failures', () async {
    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[1, 2, 3]),
      pickSavePath:
          ({required suggestedFileName, String? dialogTitle}) async =>
              '/tmp/result.webp',
      writeFile: (_, __) async => throw Exception('boom'),
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, '保存失败，请稍后重试');
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
    );

    expect(permissionRequested, isTrue);
    expect(savedBytes, Uint8List.fromList(const <int>[4, 5, 6]));
    expect(savedFileName, 'thumb.webp');
    expect(result.status, ImageSaveStatus.success);
    expect(result.message, '已保存到系统相册');
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
      );

      expect(result.status, ImageSaveStatus.failed);
      expect(result.message, '没有相册权限，无法保存图片');
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
    );

    expect(result.status, ImageSaveStatus.failed);
    expect(result.message, '保存失败，请稍后重试');
  });

  test('image save service triggers browser download on web', () async {
    Uint8List? savedBytes;
    String? savedFileName;

    final service = ImageSaveService(
      fetchBytes: (_) async => Uint8List.fromList(const <int>[7, 8, 9]),
      resolvePlatform: () => ImageSavePlatform.web,
      saveByBrowserDownload: ({required bytes, required fileName}) async {
        savedBytes = bytes;
        savedFileName = fileName;
        return true;
      },
    );

    final result = await service.saveImageFromUrl(
      imageUrl: '/images/thumb.webp',
      fileName: 'thumb.webp',
    );

    expect(savedBytes, Uint8List.fromList(const <int>[7, 8, 9]));
    expect(savedFileName, 'thumb.webp');
    expect(result.status, ImageSaveStatus.success);
    expect(result.message, '已触发浏览器下载');
  });
}
