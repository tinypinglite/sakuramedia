import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_batch_detail_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_rapid_upload_history_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_meta_chip.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 秒传批次历史 section：批次 tab 主体。
///
/// 数据源：`mediaRapidUploadHistoryProvider`（批次分页）+ `mediaLibrariesProvider`
/// （目标库名映射）+ `mediaRapidUploadBatchDetailProvider`（展开时按 batchId 拉
/// items 明细）。重试动作由父页承担，因为需要处理 batch 级 spinner + toast。
///
/// 批次历史与明细都使用有界 builder 列表：历史直接消费页面滚动 Sliver，明细放入
/// 桌面弹窗，避免任一层把累计条目全部挂进渲染树。
class RapidUploadHistorySection extends StatelessWidget {
  const RapidUploadHistorySection({
    super.key,
    required this.scrollController,
    required this.onRetry,
    required this.retryingBatchId,
  });

  final ScrollController scrollController;
  final Future<void> Function(MediaRapidUploadBatchListItemDto batch) onRetry;
  final int? retryingBatchId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const Key('media-management-batch-scroll-view'),
      controller: scrollController,
      slivers: [
        const SliverToBoxAdapter(child: _RapidUploadHistoryHeader()),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        _RapidUploadHistoryBodySliver(
          retryingBatchId: retryingBatchId,
          onRetry: onRetry,
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xxl)),
      ],
    );
  }
}

class _RapidUploadHistoryHeader extends ConsumerWidget {
  const _RapidUploadHistoryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(mediaRapidUploadHistoryProvider);
    final total = asyncState.value?.total ?? 0;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;
    return AppFilterTotalHeader(
      leading: Text(
        '秒传任务按批次记录执行状态，失败项可以在批次结束后重新提交。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      ),
      totalText: '共 $total 个批次',
      totalKey: const Key('media-management-batch-total'),
      trailing: AppIconButton(
        key: const Key('media-management-batch-refresh-button'),
        tooltip: isInitialLoading ? '刷新中' : '刷新批次',
        onPressed:
            isInitialLoading
                ? null
                : () async {
                  final message =
                      await ref
                          .read(mediaRapidUploadHistoryProvider.notifier)
                          .refresh();
                  if (message != null) showToast(message);
                },
        icon: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}

class _RapidUploadHistoryBodySliver extends ConsumerWidget {
  const _RapidUploadHistoryBodySliver({
    required this.retryingBatchId,
    required this.onRetry,
  });

  final int? retryingBatchId;
  final Future<void> Function(MediaRapidUploadBatchListItemDto batch) onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(mediaRapidUploadHistoryProvider);
    final libraries =
        ref.watch(mediaLibrariesProvider).value?.libraries ?? const [];
    return SliverPagedAsyncSection<
      PagedListState<MediaRapidUploadBatchListItemDto>,
      MediaRapidUploadBatchListItemDto
    >(
      asyncState: asyncState,
      pagedOf: (s) => s,
      itemSpacing: context.appSpacing.md,
      initialErrorMessage: '秒传批次加载失败，请稍后重试',
      emptyMessage: '暂无秒传批次记录。选择媒体后可以从上方发起秒传。',
      initialRetryKey: const Key('media-management-batch-retry-button'),
      onReload:
          () => unawaited(
            ref.read(mediaRapidUploadHistoryProvider.notifier).reload(),
          ),
      onLoadMore:
          () => unawaited(
            ref.read(mediaRapidUploadHistoryProvider.notifier).loadMore(),
          ),
      itemBuilder:
          (context, batch, _) => _RapidUploadBatchCard(
            batch: batch,
            libraries: libraries,
            isRetrying: retryingBatchId == batch.id,
            canRetry:
                retryingBatchId == null &&
                batch.state.isTerminal &&
                batch.hasRetryable,
            onRetry: () => unawaited(onRetry(batch)),
            onOpenDetail:
                () => _showRapidUploadBatchDetailDialog(context, batch),
          ),
    );
  }
}

Future<void> _showRapidUploadBatchDetailDialog(
  BuildContext context,
  MediaRapidUploadBatchListItemDto batch,
) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AppDesktopDialog(
          dialogKey: Key('rapid-upload-batch-detail-dialog-${batch.id}'),
          closeButtonKey: Key('rapid-upload-batch-detail-close-${batch.id}'),
          width: dialogContext.appLayoutTokens.dialogWidthMd,
          height: MediaQuery.sizeOf(dialogContext).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '批次 #${batch.id} 明细',
                style: resolveAppTextStyle(
                  dialogContext,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: dialogContext.appSpacing.xs),
              Text(
                '共 ${batch.totalCount} 项 · 成功 ${batch.succeededCount} · 失败 ${batch.failedCount + batch.cleanupFailedCount}',
                style: resolveAppTextStyle(
                  dialogContext,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              SizedBox(height: dialogContext.appSpacing.lg),
              Expanded(child: _RapidUploadBatchDetailBody(batchId: batch.id)),
            ],
          ),
        ),
  );
}

class _RapidUploadBatchCard extends StatelessWidget {
  const _RapidUploadBatchCard({
    required this.batch,
    required this.libraries,
    required this.isRetrying,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenDetail,
  });

  final MediaRapidUploadBatchListItemDto batch;
  final List<MediaLibraryDto> libraries;
  final bool isRetrying;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetail;

  bool get _hasDetails => batch.totalCount > 0;

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
                tone:
                    batch.succeededCount > 0
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
              if (_hasDetails) ...[
                SizedBox(width: spacing.md),
                AppButton(
                  key: Key('rapid-upload-batch-toggle-${batch.id}'),
                  label: '查看明细（${batch.totalCount}）',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: onOpenDetail,
                ),
              ],
              if (canRetry || isRetrying) ...[
                SizedBox(width: spacing.sm),
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

/// 单批次明细展开区：`autoDispose family` 拉 batch detail，展示 loading / error /
/// items 列表；items 保持后端顺序（后端已按 id 升序 = 提交顺序）。
class _RapidUploadBatchDetailBody extends ConsumerWidget {
  const _RapidUploadBatchDetailBody({required this.batchId});

  final int batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mediaRapidUploadBatchDetailProvider(batchId));
    final spacing = context.appSpacing;

    if (detailAsync.isLoading && !detailAsync.hasValue) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: context.appComponentTokens.movieCardLoaderSize,
            height: context.appComponentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth:
                  context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }
    if (detailAsync.hasError && !detailAsync.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '批次明细加载失败，请重试',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.error,
            ),
          ),
          SizedBox(height: spacing.sm),
          AppButton(
            key: Key('rapid-upload-batch-detail-retry-$batchId'),
            label: '重试',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed:
                () => ref.invalidate(
                  mediaRapidUploadBatchDetailProvider(batchId),
                ),
          ),
        ],
      );
    }
    final detail = detailAsync.value!;
    if (detail.items.isEmpty) {
      return Text(
        '这个批次没有明细记录。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      );
    }
    return ListView.separated(
      key: Key('rapid-upload-batch-detail-list-$batchId'),
      itemCount: detail.items.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder:
          (context, index) => _RapidUploadItemRow(item: detail.items[index]),
    );
  }
}

/// 单条秒传明细行：状态 badge + 路径 + 元信息（大小 / 完成时间）+ 失败时的
/// `errorMessage`。`surfaceMuted` 灰底卡壳与父层白卡拉开层次。
class _RapidUploadItemRow extends StatelessWidget {
  const _RapidUploadItemRow({required this.item});

  final MediaRapidUploadItemDto item;

  bool get _isFailure =>
      item.state == MediaRapidUploadItemState.failed ||
      item.state == MediaRapidUploadItemState.cleanupFailed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final mutedStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final finishedLabel = formatUpdatedAtLabel(item.finishedAt);
    final metaBits = <String>[
      formatFileSize(item.sourceSizeBytes),
      if (finishedLabel != null) '完成 $finishedLabel',
    ];
    final displayPath =
        item.targetName?.isNotEmpty == true
            ? item.targetName!
            : item.sourcePath;
    return Container(
      key: Key('rapid-upload-item-${item.id}'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBadge(
                label: item.state.label,
                tone: _itemStateTone(item.state),
                size: AppBadgeSize.compact,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  displayPath,
                  key: Key('rapid-upload-item-path-${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
            ],
          ),
          if (displayPath != item.sourcePath) ...[
            SizedBox(height: spacing.xs),
            Text(
              item.sourcePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mutedStyle,
            ),
          ],
          if (metaBits.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            Wrap(
              spacing: spacing.md,
              runSpacing: spacing.xs,
              children: [
                for (final bit in metaBits) Text(bit, style: mutedStyle),
              ],
            ),
          ],
          if (_isFailure && (item.errorMessage ?? '').trim().isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              item.errorMessage!,
              key: Key('rapid-upload-item-error-${item.id}'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          ],
        ],
      ),
    );
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

AppBadgeTone _itemStateTone(MediaRapidUploadItemState state) {
  return switch (state) {
    MediaRapidUploadItemState.pending => AppBadgeTone.neutral,
    MediaRapidUploadItemState.running => AppBadgeTone.info,
    MediaRapidUploadItemState.succeeded => AppBadgeTone.success,
    MediaRapidUploadItemState.failed => AppBadgeTone.error,
    MediaRapidUploadItemState.cleanupFailed => AppBadgeTone.error,
    MediaRapidUploadItemState.unknown => AppBadgeTone.neutral,
  };
}
