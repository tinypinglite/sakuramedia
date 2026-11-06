import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

/// 索引器设置的标准保存流程：校验完整草稿 → PATCH → 成功/失败 toast。
///
/// 桌面页和移动编辑器共用这一份校验与保存实现；保存时机仍由两端各自决定：
/// 桌面弹窗先返回 DTO，再由页面保存；移动抽屉保存成功后才关闭。
Future<bool> saveIndexerDraft({
  required WidgetRef ref,
  required BuildContext context,
  required List<IndexerEntryDto> indexers,
  required String successToast,
  String? failureFallback,
}) async {
  final l10n = AppLocalizations.of(context);
  final duplicateNames = findDuplicateIndexerNames(indexers);
  if (duplicateNames.isNotEmpty) {
    showToast(
      l10n.indexerNameDuplicateWithName(duplicateNames.first),
      tone: AppToastTone.warning,
    );
    return false;
  }

  final availableClientIds =
      ref
          .read(downloadClientsProvider)
          .value
          ?.map((client) => client.id)
          .toSet() ??
      const <int>{};
  for (final item in indexers) {
    if (!isValidIndexerHttpUrl(item.url)) {
      showToast(l10n.indexerUrlMustBeHttp, tone: AppToastTone.warning);
      return false;
    }
    if (!isSupportedIndexerKind(item.kind)) {
      showToast(l10n.indexerUnsupportedKind, tone: AppToastTone.warning);
      return false;
    }
    if (!item.downloadClientIds.every(availableClientIds.contains)) {
      showToast(l10n.indexerDownloadersInvalid, tone: AppToastTone.error);
      return false;
    }
  }

  try {
    await ref
        .read(indexerSettingsProvider.notifier)
        .saveDraft(indexers: indexers);
    if (!context.mounted) return false;
    showToast(successToast, tone: AppToastTone.success);
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    showToast(
      apiErrorMessage(
        error,
        fallback: failureFallback ?? l10n.indexerSaveFailed,
        l10n: l10n,
      ),
      tone: AppToastTone.error,
    );
    return false;
  }
}
