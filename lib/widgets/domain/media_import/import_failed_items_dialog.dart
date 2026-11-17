import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/data/import_failed_item_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_failure_reason_descriptions.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/failed_import_items_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media_import/import_metadata_match_view.dart';

/// 打开某个导入任务的失败文件处理弹层：桌面为居中对话框，移动端为底部抽屉。
///
/// 列表只展示后端失败项资源；「手动匹配」允许用户指定番号搜索元数据并用选中
/// 候选重试导入单个文件。
Future<void> showImportFailedItemsDialog({
  required BuildContext context,
  required int taskRunId,
  required String taskName,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('import-failed-items-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopHeight: MediaQuery.sizeOf(context).height * 0.72,
    builder: (_) =>
        _ImportFailedItemsDialogBody(taskRunId: taskRunId, taskName: taskName),
  );
}

class _ImportFailedItemsDialogBody extends ConsumerStatefulWidget {
  const _ImportFailedItemsDialogBody({
    required this.taskRunId,
    required this.taskName,
  });

  final int taskRunId;
  final String taskName;

  @override
  ConsumerState<_ImportFailedItemsDialogBody> createState() =>
      _ImportFailedItemsDialogBodyState();
}

class _ImportFailedItemsDialogBodyState
    extends ConsumerState<_ImportFailedItemsDialogBody> {
  static const Duration _pollingInterval = Duration(seconds: 3);

  Timer? _pollTimer;
  ImportFailedItemDto? _matchingItem;

  @override
  void initState() {
    super.initState();
    // 重试任务在后台执行：仅当列表里存在「重试中」条目时轮询，其余时间不发请求。
    _pollTimer = Timer.periodic(_pollingInterval, (_) => _refreshQueuedItems());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _refreshQueuedItems() {
    final items = ref.read(failedImportItemsProvider(widget.taskRunId)).value;
    if (items == null) return;
    final hasQueued = items.any(
      (item) => item.state == ImportFailedItemState.queued,
    );
    if (hasQueued) {
      ref.invalidate(failedImportItemsProvider(widget.taskRunId));
    }
  }

  void _handleRetried() {
    ref.invalidate(failedImportItemsProvider(widget.taskRunId));
    setState(() => _matchingItem = null);
  }

  @override
  Widget build(BuildContext context) {
    final matchingItem = _matchingItem;
    if (matchingItem != null) {
      return ImportMetadataMatchView(
        taskRunId: widget.taskRunId,
        item: matchingItem,
        onBack: () => setState(() => _matchingItem = null),
        onRetried: _handleRetried,
      );
    }
    final itemsAsync = ref.watch(failedImportItemsProvider(widget.taskRunId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).widgetMediaImportFailedSkippedTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          _subtitle(itemsAsync.value),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        Expanded(child: _buildContent(itemsAsync)),
      ],
    );
  }

  String _subtitle(List<ImportFailedItemDto>? items) {
    if (items == null) return widget.taskName;
    final l10n = AppLocalizations.of(context);
    final pendingFailures = items
        .where(
          (item) =>
              !item.isSkipped && item.state != ImportFailedItemState.resolved,
        )
        .length;
    final skippedCount = items.where((item) => item.isSkipped).length;
    final parts = <String>[
      if (pendingFailures > 0)
        l10n.widgetMediaImportSubtitlePendingFailures(pendingFailures),
      if (skippedCount > 0)
        l10n.widgetMediaImportSubtitleSkipped(skippedCount),
    ];
    if (parts.isEmpty) {
      return l10n.widgetMediaImportSubtitleAllProcessed(widget.taskName);
    }
    return '${widget.taskName} · ${parts.join(' · ')}';
  }

  Widget _buildContent(AsyncValue<List<ImportFailedItemDto>> itemsAsync) {
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            message: AppLocalizations.of(
              context,
            ).widgetMediaImportNoFailedOrSkippedFiles,
          );
        }
        final failures = items.where((item) => !item.isSkipped).toList();
        final skipped = items.where((item) => item.isSkipped).toList();
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failures.isNotEmpty)
                AppSettingsGroup(
                  header: AppLocalizations.of(
                    context,
                  ).widgetMediaImportFailedFilesHeader,
                  children: [
                    for (final item in failures)
                      _FailedItemRow(
                        item: item,
                        onMatch: () => setState(() => _matchingItem = item),
                      ),
                  ],
                ),
              if (failures.isNotEmpty && skipped.isNotEmpty)
                SizedBox(height: context.appSpacing.xl),
              if (skipped.isNotEmpty)
                AppSettingsGroup(
                  header: AppLocalizations.of(
                    context,
                  ).widgetMediaImportSkipped,
                  children: [
                    for (final item in skipped) _FailedItemRow(item: item),
                  ],
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: AppInlineSpinner()),
      error: (error, _) => AppEmptyState(
        message: apiErrorMessage(
          error,
          fallback: AppLocalizations.of(
            context,
          ).widgetMediaImportFailedItemsLoadFailed,
          l10n: AppLocalizations.of(context),
        ),
        onRetry: () =>
            ref.invalidate(failedImportItemsProvider(widget.taskRunId)),
        retryKey: const Key('import-failed-items-retry'),
      ),
    );
  }
}

class _FailedItemRow extends StatelessWidget {
  const _FailedItemRow({required this.item, this.onMatch});

  final ImportFailedItemDto item;

  /// 仅失败分组传入；已跳过条目只做信息展示。
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (stateLabel, stateTone) = item.isSkipped
        ? (l10n.widgetMediaImportSkipped, AppBadgeTone.neutral)
        : switch (item.state) {
            ImportFailedItemState.pending => (
              l10n.widgetMediaImportStatePending,
              AppBadgeTone.neutral,
            ),
            ImportFailedItemState.queued => (
              l10n.widgetMediaImportStateRetrying,
              AppBadgeTone.warning,
            ),
            ImportFailedItemState.resolved => (
              l10n.widgetMediaImportStateImported,
              AppBadgeTone.success,
            ),
          };
    final onMatch = this.onMatch;
    final lastRetryError = item.lastRetryError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingCell(
          title: item.fileName,
          subtitle:
              '${describeImportFailureReason(item.reason, l10n)} · '
              '${formatFileSize(item.sizeBytes)}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(
                label: stateLabel,
                tone: stateTone,
                size: AppBadgeSize.compact,
              ),
              if (item.canManualSearch && onMatch != null) ...[
                SizedBox(width: context.appSpacing.sm),
                AppButton(
                  key: Key('import-failed-item-match-${item.id}'),
                  size: AppButtonSize.xSmall,
                  label: l10n.widgetMediaImportManualMatch,
                  onPressed: onMatch,
                ),
              ],
            ],
          ),
        ),
        if (lastRetryError != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.appSpacing.lg,
              0,
              context.appSpacing.lg,
              context.appSpacing.md,
            ),
            child: Text(
              l10n.widgetMediaImportRetryFailed(lastRetryError),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          ),
      ],
    );
  }
}
