import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum ImageSaveStatus { success, cancelled, failed }

enum ImageSavePlatform { desktop, mobile, unsupported }

class ImageSaveResult {
  const ImageSaveResult({required this.status, this.savedPath, this.message});

  final ImageSaveStatus status;
  final String? savedPath;
  final String? message;
}

typedef ImageBytesFetcher = Future<Uint8List> Function(String imageUrl);
typedef ImageSavePathPicker =
    Future<String?> Function({
      required String suggestedFileName,
      String? dialogTitle,
    });
typedef ImageFileWriter = Future<void> Function(String path, Uint8List bytes);
typedef ImageSavePlatformResolver = ImageSavePlatform Function();
typedef ImageGalleryPermissionRequester = Future<bool> Function();
typedef ImageGallerySaver =
    Future<bool> Function({required Uint8List bytes, required String fileName});

class ImageSaveService {
  ImageSaveService({
    required this.fetchBytes,
    ImageSavePathPicker? pickSavePath,
    ImageFileWriter? writeFile,
    ImageSavePlatformResolver? resolvePlatform,
    ImageGalleryPermissionRequester? requestGalleryPermission,
    ImageGallerySaver? saveToGallery,
  }) : pickSavePath = pickSavePath ?? _defaultPickSavePath,
       writeFile = writeFile ?? _defaultWriteFile,
       resolvePlatform = resolvePlatform ?? _defaultResolvePlatform,
       requestGalleryPermission =
           requestGalleryPermission ?? _defaultRequestGalleryPermission,
       saveToGallery = saveToGallery ?? _defaultSaveToGallery;

  final ImageBytesFetcher fetchBytes;
  final ImageSavePathPicker pickSavePath;
  final ImageFileWriter writeFile;
  final ImageSavePlatformResolver resolvePlatform;
  final ImageGalleryPermissionRequester requestGalleryPermission;
  final ImageGallerySaver saveToGallery;

  Future<ImageSaveResult> saveImageFromUrl({
    required String imageUrl,
    String? fileName,
    String? dialogTitle,
  }) async {
    try {
      final suggestedFileName =
          (fileName == null || fileName.trim().isEmpty)
              ? _resolveFileName(imageUrl)
              : fileName.trim();

      switch (resolvePlatform()) {
        case ImageSavePlatform.desktop:
          final savePath = await pickSavePath(
            suggestedFileName: suggestedFileName,
            dialogTitle: dialogTitle,
          );
          if (savePath == null || savePath.trim().isEmpty) {
            return const ImageSaveResult(status: ImageSaveStatus.cancelled);
          }
          final bytes = await fetchBytes(imageUrl);
          await writeFile(savePath, bytes);
          return ImageSaveResult(
            status: ImageSaveStatus.success,
            savedPath: savePath,
            message: '图片已保存',
          );
        case ImageSavePlatform.mobile:
          final granted = await requestGalleryPermission();
          if (!granted) {
            return const ImageSaveResult(
              status: ImageSaveStatus.failed,
              message: '没有相册权限，无法保存图片',
            );
          }
          final bytes = await fetchBytes(imageUrl);
          final saved = await saveToGallery(
            bytes: bytes,
            fileName: suggestedFileName,
          );
          if (!saved) {
            return const ImageSaveResult(
              status: ImageSaveStatus.failed,
              message: '保存失败，请稍后重试',
            );
          }
          return const ImageSaveResult(
            status: ImageSaveStatus.success,
            message: '已保存到系统相册',
          );
        case ImageSavePlatform.unsupported:
          return const ImageSaveResult(
            status: ImageSaveStatus.failed,
            message: '当前平台暂不支持保存图片',
          );
      }
    } on PlatformException catch (error) {
      return ImageSaveResult(
        status: ImageSaveStatus.failed,
        message: error.message ?? '保存失败，请稍后重试',
      );
    } catch (_) {
      return const ImageSaveResult(
        status: ImageSaveStatus.failed,
        message: '保存失败，请稍后重试',
      );
    }
  }

  static Future<String?> _defaultPickSavePath({
    required String suggestedFileName,
    String? dialogTitle,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: <String>[_guessImageFileExtension(suggestedFileName)],
    );
  }

  static Future<void> _defaultWriteFile(String path, Uint8List bytes) {
    return File(path).writeAsBytes(bytes, flush: true);
  }

  static ImageSavePlatform _defaultResolvePlatform() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return ImageSavePlatform.desktop;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return ImageSavePlatform.mobile;
    }
    return ImageSavePlatform.unsupported;
  }

  static Future<bool> _defaultRequestGalleryPermission() async {
    if (Platform.isIOS) {
      final photosAddOnly = await Permission.photosAddOnly.request();
      if (photosAddOnly.isGranted || photosAddOnly.isLimited) {
        return true;
      }
      final photos = await Permission.photos.request();
      return photos.isGranted || photos.isLimited;
    }
    if (Platform.isAndroid) {
      final photos = await Permission.photos.request();
      if (photos.isGranted || photos.isLimited) {
        return true;
      }
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    return false;
  }

  static Future<bool> _defaultSaveToGallery({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final result = await ImageGallerySaverPlus.saveImage(
      bytes,
      name: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      quality: 100,
    );
    if (result is! Map) {
      return false;
    }
    final success =
        result['isSuccess'] ?? result['success'] ?? result['is_success'];
    if (success is bool) {
      return success;
    }
    if (success is int) {
      return success == 1;
    }
    if (success is String) {
      return success == '1' || success.toLowerCase() == 'true';
    }
    return false;
  }

  static String _resolveFileName(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final segment =
        uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final normalized = segment.split('?').first.trim();
    if (normalized.isNotEmpty) {
      return normalized.contains('.')
          ? normalized
          : '$normalized.${_guessImageFileExtension(normalized)}';
    }
    return 'image_${DateTime.now().millisecondsSinceEpoch}.webp';
  }

  static String _guessImageFileExtension(String fileName) {
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
    return 'webp';
  }
}
