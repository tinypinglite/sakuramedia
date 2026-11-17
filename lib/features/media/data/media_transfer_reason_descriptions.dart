import 'package:sakuramedia/l10n/app_localizations.dart';

/// 媒体迁移失败原因（`files[].reason_code`）到当前语言短文案的映射。
///
/// 只覆盖当前迁移流程会写入的原因；未知取值回退原值，空值回退通用未知文案。
String describeMediaTransferReason(String code, AppLocalizations l10n) {
  return switch (code) {
    'media_busy' => l10n.mediaTransferReasonMediaBusy,
    'library_changed' => l10n.mediaTransferReasonLibraryChanged,
    'media_unavailable' => l10n.mediaTransferReasonMediaUnavailable,
    'source_changed' => l10n.mediaTransferReasonSourceChanged,
    'stage_failed' => l10n.mediaTransferReasonStageFailed,
    'switch_failed' => l10n.mediaTransferReasonSwitchFailed,
    'target_verification_failed' =>
      l10n.mediaTransferReasonTargetVerificationFailed,
    'source_cleanup_failed' => l10n.mediaTransferReasonSourceCleanupFailed,
    'cleanup_unconfirmed' => l10n.mediaTransferReasonCleanupUnconfirmed,
    'interrupted' => l10n.mediaTransferReasonInterrupted,
    'transfer_setup_failed' => l10n.mediaTransferReasonTransferSetupFailed,
    'target_not_available' => l10n.mediaTransferReasonTargetNotAvailable,
    _ => code.isEmpty ? l10n.mediaTransferReasonUnknown : code,
  };
}
