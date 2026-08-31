import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_meta_line.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_path_line.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';

/// 「重复媒体」列表：按归属类型切换，按重复文件组展示，并支持逐条清理。
class DuplicateMediaSection extends ConsumerWidget {
  const DuplicateMediaSection({
    super.key,
    required this.scrollController,
    required this.kind,
    required this.onKindChanged,
    required this.keyPrefix,
    required this.mobile,
    required this.onRefresh,
    this.onOpenMovieDetail,
  });

  final ScrollController scrollController;
  final MediaListItemKind kind;
  final ValueChanged<MediaListItemKind> onKindChanged;
  final String keyPrefix;
  final bool mobile;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> deleteMedia(
      DuplicateMediaGroupDto group,
      MediaListItemDto item,
    ) async {
      final remainingCount = group.mediaItems.length - 1;
      final remainingHint = remainingCount >= 2
          ? '删除后该组还会保留 $remainingCount 项媒体。'
          : '删除后该组将不再属于重复媒体。';
      final confirmed = await showAppConfirmDialog(
        context,
        title: '删除重复媒体',
        message: '确认删除“${item.fileName}”及对应文件？$remainingHint',
        confirmLabel: '删除',
        danger: true,
        dialogKey: Key('$keyPrefix-duplicate-delete-dialog-${item.id}'),
        confirmKey: Key(
          '$keyPrefix-duplicate-delete-confirm-button-${item.id}',
        ),
        cancelKey: Key('$keyPrefix-duplicate-delete-cancel-button-${item.id}'),
        onConfirm: () async {
          await ref
              .read(duplicateMediaProvider(kind).notifier)
              .deleteDuplicateMedia(mediaId: item.id);
          ref.read(mediaBrowseProvider.notifier).removeItemsByIds([item.id]);
        },
        failureFallback: '删除重复媒体失败',
      );
      if (confirmed && context.mounted) {
        showToast('重复媒体已删除');
      }
    }

    return CustomScrollView(
      key: Key('$keyPrefix-duplicate-scroll-view'),
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _DuplicateMediaHeader(
            kind: kind,
            keyPrefix: keyPrefix,
            onKindChanged: onKindChanged,
            onRefresh: onRefresh,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        _DuplicateMediaBodySliver(
          kind: kind,
          keyPrefix: keyPrefix,
          mobile: mobile,
          onOpenMovieDetail: onOpenMovieDetail,
          onDelete: (group, item) => unawaited(deleteMedia(group, item)),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xxl)),
      ],
    );
  }
}

class _DuplicateMediaHeader extends ConsumerWidget {
  const _DuplicateMediaHeader({
    required this.kind,
    required this.keyPrefix,
    required this.onKindChanged,
    required this.onRefresh,
  });

  final MediaListItemKind kind;
  final String keyPrefix;
  final ValueChanged<MediaListItemKind> onKindChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(duplicateMediaProvider(kind));
    final total = asyncState.value?.total ?? 0;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterTotalHeader(
          leading: Align(
            alignment: Alignment.centerLeft,
            child: _DuplicateKindSwitcher(
              kind: kind,
              keyPrefix: keyPrefix,
              onChanged: onKindChanged,
            ),
          ),
          totalText: '共 $total 组',
          totalKey: Key('$keyPrefix-duplicate-total-text'),
          trailing: AppIconButton(
            key: Key('$keyPrefix-duplicate-refresh-button'),
            tooltip: isInitialLoading ? '刷新中' : '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isInitialLoading ? null : onRefresh,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          '按文件内容指纹聚合同一文件的媒体记录。删除前请确认至少保留一个可用副本。',
          key: Key('$keyPrefix-duplicate-description'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }
}

class _DuplicateKindSwitcher extends StatelessWidget {
  const _DuplicateKindSwitcher({
    required this.kind,
    required this.keyPrefix,
    required this.onChanged,
  });

  final MediaListItemKind kind;
  final String keyPrefix;
  final ValueChanged<MediaListItemKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return DecoratedBox(
      key: Key('$keyPrefix-duplicate-kind-switcher'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextButton(
            key: Key('$keyPrefix-duplicate-kind-jav'),
            label: MediaListItemKind.jav.label,
            size: AppTextButtonSize.xSmall,
            isSelected: kind == MediaListItemKind.jav,
            onPressed: () => onChanged(MediaListItemKind.jav),
          ),
          SizedBox(width: spacing.xs),
          AppTextButton(
            key: Key('$keyPrefix-duplicate-kind-video'),
            label: MediaListItemKind.video.label,
            size: AppTextButtonSize.xSmall,
            isSelected: kind == MediaListItemKind.video,
            onPressed: () => onChanged(MediaListItemKind.video),
          ),
        ],
      ),
    );
  }
}

class _DuplicateMediaBodySliver extends ConsumerWidget {
  const _DuplicateMediaBodySliver({
    required this.kind,
    required this.keyPrefix,
    required this.mobile,
    required this.onDelete,
    this.onOpenMovieDetail,
  });

  final MediaListItemKind kind;
  final String keyPrefix;
  final bool mobile;
  final void Function(DuplicateMediaGroupDto group, MediaListItemDto item)
  onDelete;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPaged = ref.watch(
      duplicateMediaProvider(
        kind,
      ).select((asyncState) => asyncState.whenData((state) => state)),
    );
    return SliverPagedAsyncSection<
      PagedListState<DuplicateMediaGroupDto>,
      DuplicateMediaGroupDto
    >(
      asyncState: asyncPaged,
      pagedOf: (state) => state,
      itemSpacing: context.appSpacing.lg,
      initialErrorMessage: '重复媒体加载失败，请稍后重试',
      emptyMessage: '当前类型没有发现重复文件。',
      initialRetryKey: Key('$keyPrefix-duplicate-initial-retry-button'),
      onReload: () =>
          unawaited(ref.read(duplicateMediaProvider(kind).notifier).reload()),
      onLoadMore: () =>
          unawaited(ref.read(duplicateMediaProvider(kind).notifier).loadMore()),
      itemBuilder: (context, group, index) => _DuplicateMediaGroupCard(
        key: Key('$keyPrefix-duplicate-group-${_groupKey(group, index)}'),
        group: group,
        keyPrefix: keyPrefix,
        mobile: mobile,
        onDelete: onDelete,
        onOpenMovieDetail: onOpenMovieDetail,
      ),
    );
  }

  String _groupKey(DuplicateMediaGroupDto group, int index) {
    return group.mediaItems.isEmpty
        ? 'index-$index'
        : '${group.mediaItems.first.id}';
  }
}

class _DuplicateMediaGroupCard extends StatelessWidget {
  const _DuplicateMediaGroupCard({
    super.key,
    required this.group,
    required this.keyPrefix,
    required this.mobile,
    required this.onDelete,
    this.onOpenMovieDetail,
  });

  final DuplicateMediaGroupDto group;
  final String keyPrefix;
  final bool mobile;
  final void Function(DuplicateMediaGroupDto group, MediaListItemDto item)
  onDelete;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < group.mediaItems.length; index++) ...[
              if (index > 0)
                Divider(height: spacing.lg, color: context.appColors.divider),
              _DuplicateMediaItemRow(
                key: Key(
                  '$keyPrefix-duplicate-item-${group.mediaItems[index].id}',
                ),
                item: group.mediaItems[index],
                keyPrefix: keyPrefix,
                mobile: mobile,
                onDelete: () => onDelete(group, group.mediaItems[index]),
                onOpenMovieDetail: onOpenMovieDetail,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DuplicateMediaItemRow extends StatelessWidget {
  const _DuplicateMediaItemRow({
    super.key,
    required this.item,
    required this.keyPrefix,
    required this.mobile,
    required this.onDelete,
    this.onOpenMovieDetail,
  });

  final MediaListItemDto item;
  final String keyPrefix;
  final bool mobile;
  final VoidCallback onDelete;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final itemContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DuplicateMediaCover(
          item: item,
          keyPrefix: keyPrefix,
          onOpenMovieDetail: onOpenMovieDetail,
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: _DuplicateMediaItemDetails(item: item, mobile: mobile),
        ),
      ],
    );
    final deleteButton = AppButton(
      key: Key('$keyPrefix-duplicate-delete-${item.id}'),
      label: '删除此项',
      size: AppButtonSize.small,
      variant: AppButtonVariant.danger,
      icon: const Icon(Icons.delete_outline_rounded),
      onPressed: onDelete,
    );

    return mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              itemContent,
              SizedBox(height: spacing.md),
              Align(alignment: Alignment.centerRight, child: deleteButton),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: itemContent),
              SizedBox(width: spacing.lg),
              deleteButton,
            ],
          );
  }
}

class _DuplicateMediaItemDetails extends ConsumerWidget {
  const _DuplicateMediaItemDetails({required this.item, required this.mobile});

  final MediaListItemDto item;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final library = item.libraryId == null
        ? null
        : ref.watch(
            mediaLibrariesProvider.select(
              (asyncState) => asyncState.value?.librariesById[item.libraryId!],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.displayHeading,
                key: Key('duplicate-media-heading-${item.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
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
        SizedBox(height: spacing.sm),
        MediaListItemMetaLine(
          item: item,
          library: library,
          spacing: mobile ? spacing.xs : spacing.sm,
          runSpacing: spacing.xs,
          showZeroFileSize: !mobile,
        ),
        SizedBox(height: spacing.xs),
        MediaListItemPathLine(
          keyPrefix: 'duplicate-media',
          item: item,
          showUpdatedAt: !mobile,
        ),
      ],
    );
  }
}

class _DuplicateMediaCover extends StatelessWidget {
  const _DuplicateMediaCover({
    required this.item,
    required this.keyPrefix,
    this.onOpenMovieDetail,
  });

  final MediaListItemDto item;
  final String keyPrefix;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final image = MediaCoverThumbnail(
      url: item.preferredCoverUrl,
      width: tokens.mobileFollowMovieThinCoverWidth,
      height: tokens.mobileFollowMovieCardHeight,
      fit: item.usesThinCover ? BoxFit.cover : BoxFit.contain,
      placeholderKey: Key('$keyPrefix-duplicate-cover-placeholder-${item.id}'),
      imageKey: Key('$keyPrefix-duplicate-cover-${item.id}'),
      placeholderBackground: context.appColors.surfacePage,
    );
    final movieNumber = item.movieNumber?.trim();
    if (!item.isJav || movieNumber == null || movieNumber.isEmpty) {
      return image;
    }
    final openMovieDetail = onOpenMovieDetail;
    if (openMovieDetail == null) return image;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('$keyPrefix-duplicate-cover-tap-${item.id}'),
        onTap: () => openMovieDetail(context, movieNumber),
        child: image,
      ),
    );
  }
}
