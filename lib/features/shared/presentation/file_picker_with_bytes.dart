import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:file_picker/file_picker.dart' show FileType;

/// 通过 file_picker 选择单个文件并读取字节的结果。
class PickedFileWithBytes {
  const PickedFileWithBytes({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// 文件选择失败（读取失败 / 平台插件不可用 / 平台异常）的领域异常。
class FilePickerWithBytesException implements Exception {
  const FilePickerWithBytesException(this.message);

  final String message;
}

/// 选择单个文件并读取字节。
///
/// 传 [maxBytes] 时优先读取平台文件长度并在读取内容前拒绝超限文件，避免把
/// 大文件整体读进内存后才报错。平台无法提供长度时仍会在读完后兜底。
Future<PickedFileWithBytes?> pickFileWithBytes({
  List<String>? allowedExtensions,
  FileType type = FileType.custom,
  String? initialDirectory,
  int? maxBytes,
  String? tooLargeMessage,
  required AppLocalizations l10n,
  required String unreadableMessage,
  required String pickerUnavailableMessage,
  required String openFailureMessage,
}) async {
  // 未显式给出超限文案时按当前语言渲染。
  final tooLarge = tooLargeMessage ?? l10n.sharedFileTooLarge;
  try {
    final file = await FilePicker.pickFile(
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: type == FileType.custom ? allowedExtensions : null,
      compressionQuality: 0,
    );
    if (file == null) {
      return null;
    }

    if (maxBytes != null) {
      int? knownLength;
      try {
        knownLength = await file.length();
      } catch (_) {
        // 平台不提供长度时继续按字节兜底。
      }
      if (knownLength != null && knownLength > maxBytes) {
        throw FilePickerWithBytesException(tooLarge);
      }
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw FilePickerWithBytesException(unreadableMessage);
    }
    if (bytes.isEmpty) {
      throw FilePickerWithBytesException(unreadableMessage);
    }
    if (maxBytes != null && bytes.length > maxBytes) {
      throw FilePickerWithBytesException(tooLarge);
    }
    return PickedFileWithBytes(bytes: bytes, fileName: file.name);
  } on MissingPluginException catch (error, stackTrace) {
    debugPrint('File picker plugin is unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw FilePickerWithBytesException(pickerUnavailableMessage);
  } on PlatformException catch (error, stackTrace) {
    debugPrint('File picker failed: ${error.message ?? error.code}');
    debugPrintStack(stackTrace: stackTrace);
    throw FilePickerWithBytesException(error.message ?? openFailureMessage);
  }
}
