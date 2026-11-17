import 'package:sakuramedia/l10n/app_localizations.dart';

/// 失败条目原因（`failed_files[].reason`）到当前语言短文案的映射。
///
/// 只覆盖导入流程当前会写入的原因；插件错误码等未知取值回退原值。
String describeImportFailureReason(String code, AppLocalizations l10n) {
  return switch (code) {
    'movie_number_not_found' => l10n.mediaImportFailureMovieNumberNotFound,
    'metadata_fetch_failed' => l10n.mediaImportFailureMetadataFetchFailed,
    'image_download_failed' => l10n.mediaImportFailureImageDownloadFailed,
    'metadata_upsert_failed' => l10n.mediaImportFailureMetadataUpsertFailed,
    'media_import_failed' => l10n.mediaImportFailureMediaImportFailed,
    'file_too_small' => l10n.mediaImportFailureFileTooSmall,
    'unsupported_format' => l10n.mediaImportFailureUnsupportedFormat,
    'already_indexed_path' => l10n.mediaImportFailureAlreadyIndexedPath,
    _ => code.isEmpty ? l10n.mediaImportFailureUnknownReason : code,
  };
}
