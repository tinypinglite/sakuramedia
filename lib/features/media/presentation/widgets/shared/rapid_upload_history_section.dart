import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

/// 秒传批次历史 section：批次 tab 主体。
///
/// 数据源：`mediaRapidUploadHistoryProvider`（批次分页）+ `mediaLibrariesProvider`
/// （目标库名映射）+ `mediaRapidUploadBatchDetailProvider`（展开时按 batchId 拉
/// items 明细）。重试动作由父页承担，因为需要处理 batch 级 spinner + toast。
///
/// 展开状态用页面级 hook `useState<Set<int>>` 管：切 tab 会丢展开态（用户展开
/// 一般立刻看，成本可忽略）。
class RapidUploadHistorySection extends HookConsumerWidget {
  const RapidUploadHistorySection({
    super.key,
    required this.onRetry,
    required this.retryingBatchId,
  });

  final Future<void> Function(MediaRapidUploadBatchListItemDto batch) onRetry;
  final int? retryingBatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(mediaRapidUploadHistoryProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final libraries = librariesAsync.value?.libraries ?? const [];
    final expandedIds = useState<Set<int>>(const <int>{});

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
        onPressed: (asyncState.isLoading && !asyncState.hasValue)
            ? null
            : () async {
                final message = await ref
                    .read(mediaRapidUploadHistoryProvider.notifier)
                    .refresh();
                if (message != null) showToast(message);
              },
        icon: const Icon(Icons.refresh_rounded),
      ),
      headerBottomSpacing: spacing.md,
      child: PagedAsyncSection<
        PagedListState<MediaRapidUploadBatchListItemDto>,
        MediaRapidUploadBatchListItemDto
      >(
        asyncState: asyncState,
        pagedOf: (s) => s,
        itemSpacing: spacing.md,
        crossAxisAlignment: CrossAxisAlignment.start,
        initialErrorMessage: '秒传批次加载失败，请稍后重试',
        emptyMessage: '暂无秒传批次记录。选择媒体后可以从上方发起秒传。',
        initialRetryKey: const Key('media-management-batch-retry-button'),
        onReload: () => unawaited(
          ref.read(mediaRapidUploadHistoryProvider.notifier).reload(),
        ),
        onLoadMore: () => unawaited(
          ref.read(mediaRapidUploadHistoryProvider.notifier).loadMore(),
        ),
        itemBuilder: (context, batch, _) => _RapidUploadBatchCard(
          batch: batch,
          libraries: libraries,
          isRetrying: retryingBatchId == batch.id,
          canRetry: retryingBatchId == null &&
              batch.state.isTerminal &&
              batch.hasRetryable,
          onRetry: () => unawaited(onRetry(batch)),
          expanded: expandedIds.value.contains(batch.id),
          onToggleExpand: () {
            final next = Set<int>.of(expandedIds.value);
            if (!next.remove(batch.id)) next.add(batch.id);
            expandedIds.value = next;
          },
        ),
      ),
    );
  }
}

class _RapidUploadBatchCard extends ConsumerWidget {
  const _RapidUploadBatchCard({
    required this.batch,
    required this.libraries,
    required this.isRetrying,
    required this.canRetry,
    required this.onRetry,
    required this.expanded,
    required this.onToggleExpand,
  });

  final MediaRapidUploadBatchListItemDto batch;
  final List<MediaLibraryDto> libraries;
  final bool isRetrying;
  final bool canRetry;
  final VoidCallback onRetry;
  final bool expanded;
  final VoidCallback onToggleExpand;

  bool get _canExpand => batch.totalCount > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (_canExpand) ...[
                SizedBox(width: spacing.md),
                AppButton(
                  key: Key('rapid-upload-batch-toggle-${batch.id}'),
                  label: expanded
                      ? '收起明细'
                      : '查看明细（${batch.totalCount}）',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: onToggleExpand,
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
          if (expanded) ...[
            SizedBox(height: spacing.md),
            _RapidUploadBatchDetailBody(batchId: batch.id),
          ],
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
    final detailAsync =
        ref.watch(mediaRapidUploadBatchDetailProvider(batchId));
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
            onPressed: () => ref.invalidate(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in detail.items)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: _RapidUploadItemRow(item: item),
          ),
      ],
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
    final displayPath = item.targetName?.isNotEmpty == true
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
          if (_isFailure &&
              (item.errorMessage ?? '').trim().isNotEmpty) ...[
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
