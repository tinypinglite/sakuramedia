import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_rapid_upload_history_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_meta_chip.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';

/// 秒传批次历史卡：批次 tab 主体。
///
/// - 外层 [AppContentCard]「秒传批次」承载 header + 刷新按钮 + 空/骨架/错误兜底；
/// - 每个批次一张 [AppContentCard]（[_RapidUploadBatchCard]），与
///   `ImportJobCard` 视觉承载对齐（同域两个"批处理作业"页读起来是一套 UI）；
/// - 翻页由 `_DesktopMediaManagementPageState._handleScroll` 滚到底触发。
class RapidUploadHistoryCard extends StatelessWidget {
  const RapidUploadHistoryCard({
    super.key,
    required this.controller,
    required this.libraries,
    required this.onRetry,
    required this.retryingBatchId,
  });

  final MediaRapidUploadHistoryController controller;
  final List<MediaLibraryDto> libraries;
  final Future<void> Function(MediaRapidUploadBatchListItemDto batch) onRetry;
  final int? retryingBatchId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: '秒传批次',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerTrailing: AppIconButton(
        key: const Key('media-management-batch-refresh-button'),
        tooltip: '刷新批次',
        onPressed: controller.isInitialLoading
            ? null
            : () => unawaited(controller.reload()),
        icon: const Icon(Icons.refresh_rounded),
      ),
      headerBottomSpacing: spacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isInitialLoading) {
      return const AppSectionSkeleton(lineCount: 6);
    }
    if (controller.initialErrorMessage != null) {
      return AppEmptyState(
        message: controller.initialErrorMessage!,
        onRetry: () => unawaited(controller.reload()),
        retryKey: const Key('media-management-batch-retry-button'),
      );
    }
    if (controller.items.isEmpty) {
      return const AppEmptyState(
        message: '暂无秒传批次记录。选择媒体后可以从上方发起秒传。',
      );
    }
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final batch in controller.items)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.md),
            child: _RapidUploadBatchCard(
              batch: batch,
              libraries: libraries,
              isRetrying: retryingBatchId == batch.id,
              canRetry: retryingBatchId == null &&
                  batch.state.isTerminal &&
                  batch.hasRetryable,
              onRetry: () => unawaited(onRetry(batch)),
            ),
          ),
        if (controller.isLoadingMore ||
            controller.loadMoreErrorMessage != null) ...[
          SizedBox(height: spacing.md),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingMore,
            errorMessage: controller.loadMoreErrorMessage,
            onRetry: controller.loadMore,
          ),
        ],
      ],
    );
  }
}

class _RapidUploadBatchCard extends StatelessWidget {
  const _RapidUploadBatchCard({
    required this.batch,
    required this.libraries,
    required this.isRetrying,
    required this.canRetry,
    required this.onRetry,
  });

  final MediaRapidUploadBatchListItemDto batch;
  final List<MediaLibraryDto> libraries;
  final bool isRetrying;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: '批次 #${batch.id}',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.sm,
      child: Column(
        key: Key('rapid-upload-batch-card-${batch.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                key: Key('rapid-upload-batch-state-${batch.id}'),
                label: batch.state.label,
                tone: _batchStateTone(batch.state),
              ),
              if (batch.retryOfBatchId != null)
                AppBadge(
                  label: '重试 #${batch.retryOfBatchId}',
                  tone: AppBadgeTone.info,
                ),
              AppMetaChip(
                icon: Icons.folder_outlined,
                label: '目标 ${_targetLibraryName()}',
              ),
              AppMetaChip(
                icon: Icons.summarize_outlined,
                label: '共 ${batch.totalCount}',
              ),
              AppMetaChip(
                key: Key('rapid-upload-batch-succeeded-${batch.id}'),
                icon: Icons.check_circle_outline_rounded,
                label: '成功 ${batch.succeededCount}',
                tone: batch.succeededCount > 0
                    ? AppTextTone.success
                    : AppTextTone.secondary,
              ),
              if (batch.failedCount > 0)
                AppMetaChip(
                  key: Key('rapid-upload-batch-failed-${batch.id}'),
                  icon: Icons.error_outline_rounded,
                  label: '失败 ${batch.failedCount}',
                  tone: AppTextTone.error,
                ),
              if (batch.cleanupFailedCount > 0)
                AppMetaChip(
                  icon: Icons.cleaning_services_outlined,
                  label: '清理失败 ${batch.cleanupFailedCount}',
                  tone: AppTextTone.error,
                ),
              if (batch.pendingCount > 0)
                AppMetaChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '进行中 ${batch.pendingCount}',
                  tone: AppTextTone.info,
                ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _timeText(),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ),
              if (canRetry || isRetrying) ...[
                SizedBox(width: spacing.md),
                AppButton(
                  key: Key('rapid-upload-batch-retry-${batch.id}'),
                  label: isRetrying ? '重试中' : '重试失败项',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  isLoading: isRetrying,
                  icon: const Icon(Icons.replay_rounded),
                  onPressed: canRetry ? onRetry : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _targetLibraryName() {
    for (final library in libraries) {
      if (library.id == batch.targetLibraryId) {
        return library.displayLabel;
      }
    }
    return '媒体库 ${batch.targetLibraryId}';
  }

  String _timeText() {
    final finished = batch.finishedAt;
    if (finished != null) {
      final label = formatUpdatedAtLabel(finished);
      return '结束于 ${label ?? '未知时间'}';
    }
    final started = batch.startedAt ?? batch.createdAt;
    if (started != null) {
      final label = formatUpdatedAtLabel(started);
      return '${batch.state.isRunning ? '进行中 · 开始于 ' : '创建于 '}${label ?? '未知时间'}';
    }
    return '时间未知';
  }
}

AppBadgeTone _batchStateTone(MediaRapidUploadBatchState state) {
  return switch (state) {
    MediaRapidUploadBatchState.pending => AppBadgeTone.info,
    MediaRapidUploadBatchState.running => AppBadgeTone.info,
    MediaRapidUploadBatchState.completed => AppBadgeTone.success,
    MediaRapidUploadBatchState.completedWithErrors => AppBadgeTone.warning,
    MediaRapidUploadBatchState.failed => AppBadgeTone.error,
    MediaRapidUploadBatchState.unknown => AppBadgeTone.neutral,
  };
}
