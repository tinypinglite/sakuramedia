import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class PluginZipFile {
  const PluginZipFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

typedef PluginZipPicker = Future<PluginZipFile?> Function();

@visibleForTesting
PluginZipPicker? debugPluginZipPicker;

class PluginZipPickerException implements Exception {
  const PluginZipPickerException(this.message);

  final String message;
}

Future<PluginZipFile?> pickPluginZip({required AppLocalizations l10n}) async {
  final override = debugPluginZipPicker;
  if (override != null) {
    return override();
  }

  try {
    final picked = await pickFileWithBytes(
      allowedExtensions: const <String>['zip'],
      unreadableMessage: l10n.pluginZipUnreadable,
      pickerUnavailableMessage: l10n.pluginZipPickerUnavailable,
      openFailureMessage: l10n.pluginZipOpenFailed,
      l10n: l10n,
    );
    if (picked == null) {
      return null;
    }
    return PluginZipFile(bytes: picked.bytes, fileName: picked.fileName);
  } on FilePickerWithBytesException catch (error) {
    throw PluginZipPickerException(error.message);
  }
}
