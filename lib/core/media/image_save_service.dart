import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sakuramedia/core/format/image_file_extension.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

enum ImageSaveStatus { success, cancelled, failed }

enum ImageSavePlatform { desktop, mobile, unsupported }

class ImageSaveResult {
  const ImageSaveResult({required this.status, this.savedPath, this.message});

  final ImageSaveStatus status;
  final String? savedPath;
  final String? message;
}

typedef ImageBytesFetcher = Future<Uint8List> Function(String imageUrl);
typedef ImageDesktopSaver =
    Future<String?> Function({
      required String suggestedFileName,
      required Uint8List bytes,
      String? dialogTitle,
    });
typedef ImageSavePlatformResolver = ImageSavePlatform Function();
typedef ImageGalleryPermissionRequester = Future<bool> Function();
typedef ImageGallerySaver =
    Future<bool> Function({required Uint8List bytes, required String fileName});

class ImageSaveService {
  ImageSaveService({
    required this.fetchBytes,
    ImageDesktopSaver? saveToDesktop,
    ImageSavePlatformResolver? resolvePlatform,
    ImageGalleryPermissionRequester? requestGalleryPermission,
    ImageGallerySaver? saveToGallery,
  }) : saveToDesktop = saveToDesktop ?? _defaultSaveToDesktop,
       resolvePlatform = resolvePlatform ?? _defaultResolvePlatform,
       requestGalleryPermission =
           requestGalleryPermission ?? _defaultRequestGalleryPermission,
       saveToGallery = saveToGallery ?? _defaultSaveToGallery;

  final ImageBytesFetcher fetchBytes;
  final ImageDesktopSaver saveToDesktop;
  final ImageSavePlatformResolver resolvePlatform;
  final ImageGalleryPermissionRequester requestGalleryPermission;
  final ImageGallerySaver saveToGallery;

  /// 保存图片。
  ///
  /// 结果文案走 [l10n] 指定的当前语言。
  Future<ImageSaveResult> saveImageFromUrl({
    required String imageUrl,
    String? fileName,
    String? dialogTitle,
    required AppLocalizations l10n,
  }) async {
    try {
      final suggestedFileName = (fileName == null || fileName.trim().isEmpty)
          ? _resolveFileName(imageUrl)
          : fileName.trim();

      switch (resolvePlatform()) {
        case ImageSavePlatform.desktop:
          final bytes = await fetchBytes(imageUrl);
          final savePath = await saveToDesktop(
            suggestedFileName: suggestedFileName,
            bytes: bytes,
            dialogTitle: dialogTitle,
          );
          if (savePath == null || savePath.trim().isEmpty) {
            return const ImageSaveResult(status: ImageSaveStatus.cancelled);
          }
          return ImageSaveResult(
            status: ImageSaveStatus.success,
            savedPath: savePath,
            message: l10n.coreImageSaveSuccess,
          );
        case ImageSavePlatform.mobile:
          final granted = await requestGalleryPermission();
          if (!granted) {
            return ImageSaveResult(
              status: ImageSaveStatus.failed,
              message: l10n.coreImageSavePermissionDenied,
            );
          }
          final bytes = await fetchBytes(imageUrl);
          final saved = await saveToGallery(
            bytes: bytes,
            fileName: suggestedFileName,
          );
          if (!saved) {
            return ImageSaveResult(
              status: ImageSaveStatus.failed,
              message: l10n.coreImageSaveFailed,
            );
          }
          return ImageSaveResult(
            status: ImageSaveStatus.success,
            message: l10n.coreImageSaveToGallery,
          );
        case ImageSavePlatform.unsupported:
          return ImageSaveResult(
            status: ImageSaveStatus.failed,
            message: l10n.coreImageSaveUnsupported,
          );
      }
    } on PlatformException catch (error) {
      return ImageSaveResult(
        status: ImageSaveStatus.failed,
        message: error.message ?? l10n.coreImageSaveFailed,
      );
    } catch (_) {
      return ImageSaveResult(
        status: ImageSaveStatus.failed,
        message: l10n.coreImageSaveFailed,
      );
    }
  }

  static Future<String?> _defaultSaveToDesktop({
    required String suggestedFileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) async {
    final extension = guessImageFileExtension(suggestedFileName);
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedFileName,
      bytes: bytes,
      mimeType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
    );
    return uri?.toFilePath();
  }

  static ImageSavePlatform _defaultResolvePlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS => ImageSavePlatform.desktop,
      TargetPlatform.android || TargetPlatform.iOS => ImageSavePlatform.mobile,
      _ => ImageSavePlatform.unsupported,
    };
  }

  static Future<bool> _defaultRequestGalleryPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final photosAddOnly = await Permission.photosAddOnly.request();
      if (photosAddOnly.isGranted || photosAddOnly.isLimited) {
        return true;
      }
      final photos = await Permission.photos.request();
      return photos.isGranted || photos.isLimited;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
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
    final segment = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
    final normalized = segment.split('?').first.trim();
    if (normalized.isNotEmpty) {
      return normalized.contains('.')
          ? normalized
          : '$normalized.${guessImageFileExtension(normalized)}';
    }
    return 'image_${DateTime.now().millisecondsSinceEpoch}.webp';
  }
}
