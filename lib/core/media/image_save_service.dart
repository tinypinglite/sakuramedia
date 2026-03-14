import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

enum ImageSaveStatus { success, cancelled, failed }

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

class ImageSaveService {
  ImageSaveService({
    required this.fetchBytes,
    ImageSavePathPicker? pickSavePath,
    ImageFileWriter? writeFile,
  }) : pickSavePath = pickSavePath ?? _defaultPickSavePath,
       writeFile = writeFile ?? _defaultWriteFile;

  final ImageBytesFetcher fetchBytes;
  final ImageSavePathPicker pickSavePath;
  final ImageFileWriter writeFile;

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
