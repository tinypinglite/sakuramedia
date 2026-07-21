import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_browse_filter_toolbar.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 「媒体管理」列表 tab 的主体：筛选头 + 白底 media card 列表。
///
/// 数据源：`mediaBrowseProvider` + `mediaLibrariesProvider`。多选、筛选、reload 全部
/// 由内部 `ref.read(...notifier)` 触发；父页只提供跨 provider 的动作（秒传弹窗、批量
/// 删除、复合刷新）。
///
/// 视觉参考「下载任务」卡片（[_DownloadTaskCard]）：页面灰底 + 每张 media card 直接浮起
/// 为独立白卡（不再套 `AppContentCard`）。多选操作全部收敛到顶部 [AppFilterTotalHeader]
/// 的 trailing，跟筛选、总数、刷新同一条行。
class MediaListSection extends ConsumerWidget {
  const MediaListSection({
    super.key,
    required this.isTriggering,
    required this.isDeleting,
    required this.onRapidUpload,
    required this.onBatchDelete,
    this.onRefresh,
  });

  /// 秒传触发中——按钮 spinner；由父页承担因为秒传流程含跨库弹窗 + api + toast。
  final bool isTriggering;

  /// 批量删除进行中——按钮 spinner + 禁用其它多选动作；父页编排 confirm + 串行循环。
  final bool isDeleting;

  /// 父页秒传入口：弹目标库对话框 → 调 `mediaApi.createMediaRapidUpload` → 从列表移除。
  final Future<void> Function() onRapidUpload;

  /// 父页批量删除入口：弹二次确认 → 串行循环 `mediaApi.deleteMedia` → 汇总 toast。
  final Future<void> Function() onBatchDelete;

  /// 可选：父页复合刷新（例如同时刷新秒传批次）；不传则默认刷新媒体列表 + 媒体库。
  final Future<void> Function()? onRefresh;

  Future<void> _defaultRefresh(WidgetRef ref) async {
    await Future.wait<void>([
      _refreshBrowse(ref),
      _refreshLibraries(ref),
    ]);
  }

  Future<void> _refreshBrowse(WidgetRef ref) async {
    final message = await ref.read(mediaBrowseProvider.notifier).refresh();
    if (message != null) showToast(message);
  }

  Future<void> _refreshLibraries(WidgetRef ref) async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (message != null) showToast(message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(mediaBrowseProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final librariesState = librariesAsync.value ?? MediaLibrariesState.empty;

    final currentState = asyncState.value;
    final total = currentState?.paged.total ?? 0;
    final selectionCount = currentState?.selectionCount ?? 0;
    final hasSelection = selectionCount > 0;
    final hasItems =
        currentState != null && currentState.paged.items.isNotEmpty;
    final filter = currentState?.filter ?? MediaBrowseFilterState.initial;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;
    final busy = isTriggering || isDeleting;
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterTotalHeader(
          leading: MediaBrowseFilterToolbar(
            filterState: filter,
            libraries: librariesState.libraries,
            onChanged: (next) => unawaited(
              ref.read(mediaBrowseProvider.notifier).applyFilterState(next),
            ),
            onReset: () => unawaited(
              ref
                  .read(mediaBrowseProvider.notifier)
                  .applyFilterState(MediaBrowseFilterState.initial),
            ),
          ),
          totalText: hasSelection
              ? '共 $total 条 · 已选 $selectionCount 项'
              : '共 $total 条',
          totalKey: const Key('media-management-total-text'),
          trailing: _MediaListActionBar(
            hasItems: hasItems,
            hasSelection: hasSelection,
            selectionCount: selectionCount,
            isTriggering: isTriggering,
            isDeleting: isDeleting,
            isInitialLoading: isInitialLoading,
            busy: busy,
            onRapidUpload: onRapidUpload,
            onBatchDelete: onBatchDelete,
            onRefresh: () =>
                unawaited((onRefresh ?? () => _defaultRefresh(ref))()),
          ),
        ),
        SizedBox(height: spacing.lg),
        PagedAsyncSection<MediaBrowseState, MediaListItemDto>(
          asyncState: asyncState,
          pagedOf: (s) => s.paged,
          itemSpacing: spacing.sm,
          initialErrorMessage: '媒体列表加载失败，请稍后重试',
          emptyMessage: '当前筛选下没有媒体记录。调整筛选条件或稍后再试。',
          initialRetryKey: const Key('media-management-initial-retry-button'),
          onReload: () =>
              unawaited(ref.read(mediaBrowseProvider.notifier).reload()),
          onLoadMore: () =>
              unawaited(ref.read(mediaBrowseProvider.notifier).loadMore()),
          itemBuilder: (context, item, _) {
            final data = asyncState.requireValue;
            final disabledReason = _disabledReasonFor(item);
            return _MediaRow(
              item: item,
              storage: resolveMediaStorageDescriptor(
                item.libraryId,
                librariesState.storageDescriptors,
              ),
              isSelected: data.isSelected(item.id),
              // 有禁选原因的行不响应 tap（且 _MediaRow 会挂 Tooltip 告诉用户原因）；
              // 后端 active_media_id 唯一约束会拒绝新批次，前端提前拦截更友好。
              disabledReason: disabledReason,
              onToggle: disabledReason != null
                  ? null
                  : () => ref
                      .read(mediaBrowseProvider.notifier)
                      .toggleSelection(item.id),
            );
          },
        ),
      ],
    );
  }
}

/// 顶栏右侧多选操作条：全选 / 清空 / 批量删除 / 秒传 / 刷新。
///
/// 无选择态：仅保留「全选本页」+「刷新」（不占空间过多，视觉上不喧宾夺主）；
/// 有选择态：追加「清空 / 批量删除 / 秒传到 115」，主/危险色收拢注意力。
class _MediaListActionBar extends ConsumerWidget {
  const _MediaListActionBar({
    required this.hasItems,
    required this.hasSelection,
    required this.selectionCount,
    required this.isTriggering,
    required this.isDeleting,
    required this.isInitialLoading,
    required this.busy,
    required this.onRapidUpload,
    required this.onBatchDelete,
    required this.onRefresh,
  });

  final bool hasItems;
  final bool hasSelection;
  final int selectionCount;
  final bool isTriggering;
  final bool isDeleting;
  final bool isInitialLoading;
  final bool busy;
  final Future<void> Function() onRapidUpload;
  final Future<void> Function() onBatchDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          key: const Key('media-management-select-all-button'),
          label: '全选本页',
          size: AppButtonSize.small,
          variant: AppButtonVariant.secondary,
          onPressed: !hasItems || busy
              ? null
              : () =>
                  ref.read(mediaBrowseProvider.notifier).selectAllLoaded(),
        ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-clear-selection-button'),
            label: '清空选择',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: busy
                ? null
                : () =>
                    ref.read(mediaBrowseProvider.notifier).clearSelection(),
          ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-batch-delete-button'),
            label: '批量删除（$selectionCount）',
            size: AppButtonSize.small,
            variant: AppButtonVariant.danger,
            icon: const Icon(Icons.delete_outline_rounded),
            isLoading: isDeleting,
            onPressed: busy ? null : onBatchDelete,
          ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-rapid-upload-button'),
            label: '秒传到 115（$selectionCount）',
            size: AppButtonSize.small,
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.cloud_upload_outlined),
            isLoading: isTriggering,
            onPressed: busy ? null : onRapidUpload,
          ),
        AppIconButton(
          key: const Key('media-management-refresh-button'),
          tooltip: isInitialLoading ? '刷新中' : '刷新',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: isInitialLoading ? null : onRefresh,
        ),
      ],
    );
  }
}

/// 单条 media 卡片：走 [AppLeftCoverCard] 外壳（封面贴左的白底卡），整卡点选、
/// 选中态外框换 `selectionBorder`（无 checkbox，靠外框传达选中）。
///
/// 内容层次（自上而下）：
/// 1) 标题栏：标题（一行）+ 可选副标题；右上贴角「失效」badge（仅无效时显示）。
/// 2) 元数据 Wrap：kind / 存储位置 / 库名 compact badge + 大小 / 时长 / 分辨率 muted 文本。
/// 3) 路径行：folder icon + 相对路径 muted；右侧「更新 …」（若有）。
///
/// 封面区独立 InkWell：JAV 项跳影片详情，视频项无跳转（videos 域没有单视频详情页）。
class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.storage,
    required this.isSelected,
    required this.onToggle,
    this.disabledReason,
  });

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final bool isSelected;

  /// 非空时行禁选：`onToggle` 应传 null，`disabledReason` 会作为 Tooltip 文案挂在整卡上。
  final String? disabledReason;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    final card = AppLeftCoverCard(
      key: Key('media-management-row-${item.id}'),
      coverWidth: componentTokens.downloadTaskCoverWidth,
      bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
      selected: isSelected,
      onTap: onToggle,
      cover: _MediaCoverSlot(item: item),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaHeadingLine(item: item),
          SizedBox(height: spacing.md),
          _MediaMetaLine(item: item, storage: storage),
          SizedBox(height: spacing.sm),
          _MediaPathLine(item: item, storage: storage),
        ],
      ),
    );

    // 项目约定没有 AppTooltip 包装件，直接用 Flutter 原生。
    final reason = disabledReason;
    if (reason != null) {
      return Tooltip(message: reason, child: card);
    }
    return card;
  }
}

/// 集中的行禁选决策：目前仅有秒传进行中一种原因，未来加新原因（例如批量删除
/// 排队中）直接在这里返回相应文案；`_MediaRow` 只关心"有无原因"。
String? _disabledReasonFor(MediaListItemDto item) {
  if (item.lastRapidUploadStatus == LastRapidUploadStatus.inProgress) {
    return '已在秒传批次中，无法加入新操作';
  }
  return null;
}

/// 封面 slot：宽图横向铺满，`BoxFit.cover` 横向裁切；JAV 且有番号 → InkWell
/// 独立可点跳详情；否则纯图/占位。
///
/// 内层 InkWell 会拦截手势不冒泡到外层"切换选中"，两层交互天然分离。
/// URL 优先取 `coverImage`（横版）而非 `thin_cover_image`（竖版 thin）。
class _MediaCoverSlot extends StatelessWidget {
  const _MediaCoverSlot({required this.item});

  final MediaListItemDto item;

  String? get _wideCoverUrl {
    final coverUrl = item.coverImage?.bestAvailableUrl.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    final thinUrl = item.thinCoverImage?.bestAvailableUrl.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final url = _wideCoverUrl;
    final image = url != null
        ? MaskedImage(
            key: Key('media-management-cover-${item.id}'),
            url: url,
            fit: BoxFit.cover,
          )
        : Container(
            key: Key('media-management-cover-placeholder-${item.id}'),
            color: colors.surfaceMuted,
            alignment: Alignment.center,
            child: Icon(
              Icons.movie_creation_outlined,
              size: context.appComponentTokens.iconSize2xl,
              color: context.appTextPalette.muted,
            ),
          );

    // JAV 且有番号：封面独立可点，跳影片详情。videos 域无单视频详情页，视频项
    // 封面保持纯图（点击冒泡到外层触发选中）。
    final movieNumber = item.movieNumber?.trim();
    if (!item.isJav || movieNumber == null || movieNumber.isEmpty) {
      return image;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('media-management-cover-tap-${item.id}'),
        onTap: () => context.pushDesktopMovieDetail(movieNumber: movieNumber),
        child: image,
      ),
    );
  }
}

/// 标题栏：标题 + 可选副标题；右上贴角「失效」badge（仅无效时）。
class _MediaHeadingLine extends StatelessWidget {
  const _MediaHeadingLine({required this.item});

  final MediaListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayHeading,
                key: Key('media-management-row-heading-${item.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (item.displaySubtitle != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  item.displaySubtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!item.valid) ...[
          SizedBox(width: spacing.sm),
          const AppBadge(
            label: '失效',
            tone: AppBadgeTone.error,
            size: AppBadgeSize.compact,
          ),
        ],
      ],
    );
  }
}

/// 元数据行：compact badge 承担分类属性（kind / 存储 / 库名），muted 文本承担
/// 数值信息（大小 / 时长 / 分辨率）。参考「下载任务」卡片的元数据 Wrap 节奏。
class _MediaMetaLine extends StatelessWidget {
  const _MediaMetaLine({required this.item, required this.storage});

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final rapidUploadBadge = _rapidUploadStatusBadge(item.lastRapidUploadStatus);
    final badges = <Widget>[
      AppBadge(
        label: item.kind.label,
        tone: item.kind == MediaListItemKind.jav
            ? AppBadgeTone.primary
            : AppBadgeTone.neutral,
        size: AppBadgeSize.compact,
      ),
      if (storage.isCloud115)
        const AppBadge(
          label: '115',
          tone: AppBadgeTone.info,
          size: AppBadgeSize.compact,
        )
      else if (storage.isLocal)
        const AppBadge(
          label: '本地',
          tone: AppBadgeTone.neutral,
          size: AppBadgeSize.compact,
        ),
      AppBadge(
        label: storage.formatLibraryText(libraryId: item.libraryId),
        tone: AppBadgeTone.neutral,
        size: AppBadgeSize.compact,
      ),
      if (rapidUploadBadge != null) rapidUploadBadge,
    ];
    final metrics = <String>[
      formatFileSize(item.fileSizeBytes),
      if (item.durationSeconds > 0)
        formatMediaDurationLabel(item.durationSeconds),
      if (item.resolution != null && item.resolution!.isNotEmpty)
        item.resolution!,
    ];
    final mutedTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...badges,
        for (final metric in metrics) Text(metric, style: mutedTextStyle),
      ],
    );
  }
}

/// 秒传状态 badge 映射：null / unknown 不显示；其余按后端语义配色。
///
/// - `in_progress` → info（当前批次未终态；同时行也被禁选）
/// - `cleanup_failed` → warning（云端已备份、本地待清理，重试仅做本地清理）
/// - `failed` → warning（其它可重试失败）
/// - `not_hit` → neutral（115 库无相同 sha1，重传大概率仍未命中）
AppBadge? _rapidUploadStatusBadge(LastRapidUploadStatus? status) {
  if (status == null || status == LastRapidUploadStatus.unknown) {
    return null;
  }
  final tone = switch (status) {
    LastRapidUploadStatus.inProgress => AppBadgeTone.info,
    LastRapidUploadStatus.cleanupFailed => AppBadgeTone.warning,
    LastRapidUploadStatus.failed => AppBadgeTone.warning,
    LastRapidUploadStatus.notHit => AppBadgeTone.neutral,
    LastRapidUploadStatus.unknown => AppBadgeTone.neutral,
  };
  // 不加 key：本行其它 badge 也没打 key；tone/label 已足够做定位与视觉区分。
  return AppBadge(
    label: status.label,
    tone: tone,
    size: AppBadgeSize.compact,
  );
}

/// 路径行：folder icon + 相对路径 muted（省略号）；右侧「更新 …」若有。
///
/// 用 icon 前缀区分于上一行元数据，让"这一行是路径"的语义一眼可辨。
class _MediaPathLine extends StatelessWidget {
  const _MediaPathLine({required this.item, required this.storage});

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = context.appTextPalette;
    final mutedTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final updatedLabel = item.updatedAt != null
        ? formatUpdatedAtLabel(item.updatedAt)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: palette.muted,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            storage.formatLocationText(item.path),
            key: Key('media-management-row-path-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedTextStyle,
          ),
        ),
        if (updatedLabel != null) ...[
          SizedBox(width: spacing.md),
          Text('更新 $updatedLabel', style: mutedTextStyle),
        ],
      ],
    );
  }
}
