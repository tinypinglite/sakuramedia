import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_info_block.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';

/// 「失效媒体」列表：后端只提供列表和删除，因此每条记录直接允许删除。
class InvalidMediaSection extends StatelessWidget {
  const InvalidMediaSection({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const Key('invalid-media-scroll-view'),
      controller: scrollController,
      slivers: [
        const SliverToBoxAdapter(child: _InvalidMediaHeader()),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        const _InvalidMediaBodySliver(),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xxl)),
      ],
    );
  }
}

class _InvalidMediaHeader extends ConsumerWidget {
  const _InvalidMediaHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerState = ref.watch(
      invalidMediaProvider.select(
        (asyncState) => (
          total: asyncState.value?.paged.total ?? 0,
          isInitialLoading: asyncState.isLoading && !asyncState.hasValue,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterTotalHeader(
          leading: const SizedBox.shrink(),
          totalText: '共 ${headerState.total} 条失效媒体',
          totalKey: const Key('invalid-media-total-text'),
          trailing: AppIconButton(
            key: const Key('invalid-media-refresh-button'),
            tooltip: headerState.isInitialLoading ? '刷新中' : '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: headerState.isInitialLoading
                ? null
                : () async {
                    final message = await ref
                        .read(invalidMediaProvider.notifier)
                        .refresh();
                    if (message != null) showToast(message);
                  },
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          '巡检标记为失效的媒体会出现在这里。确认无需保留后，可删除记录及对应文件。',
          key: const Key('invalid-media-section-description'),
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

class _InvalidMediaBodySliver extends ConsumerWidget {
  const _InvalidMediaBodySliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPaged = ref.watch(
      invalidMediaProvider.select(
        (asyncState) => asyncState.whenData((state) => state.paged),
      ),
    );
    return SliverPagedAsyncSection<
      PagedListState<InvalidMediaDto>,
      InvalidMediaDto
    >(
      asyncState: asyncPaged,
      pagedOf: (state) => state,
      itemSpacing: context.appSpacing.md,
      initialErrorMessage: '失效媒体加载失败，请稍后重试',
      emptyMessage: '当前没有失效媒体',
      initialRetryKey: const Key('invalid-media-initial-retry-button'),
      onReload: () =>
          unawaited(ref.read(invalidMediaProvider.notifier).reload()),
      onLoadMore: () =>
          unawaited(ref.read(invalidMediaProvider.notifier).loadMore()),
      itemBuilder: (context, item, _) => _InvalidMediaRowConsumer(item: item),
    );
  }
}

class _InvalidMediaRowConsumer extends ConsumerWidget {
  const _InvalidMediaRowConsumer({required this.item});

  final InvalidMediaDto item;

  Future<void> _handleDelete(
    WidgetRef ref,
    BuildContext context,
    InvalidMediaDto item,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除失效媒体',
      message: '确认删除“${item.displayTitle}”的这条失效媒体记录及对应文件？该操作不可恢复。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('invalid-media-delete-confirm-dialog'),
      confirmKey: const Key('invalid-media-delete-confirm-button'),
      cancelKey: const Key('invalid-media-delete-cancel-button'),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(invalidMediaProvider.notifier)
          .deleteInvalidMedia(mediaId: item.id);
      if (context.mounted) showToast('失效媒体已删除');
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '删除失效媒体失败'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(
      invalidMediaProvider.select(
        (asyncState) => asyncState.value?.deletingMediaId,
      ),
    );
    final librariesById = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.librariesById ?? const <int, MediaLibraryDto>{},
      ),
    );
    final library = item.libraryId == null
        ? null
        : librariesById[item.libraryId];
    final isDeleting = actionState == item.id;
    return _InvalidMediaCard(
      item: item,
      library: library,
      isDeleting: isDeleting,
      canDelete: actionState == null,
      onDelete: () => unawaited(_handleDelete(ref, context, item)),
    );
  }
}

class _InvalidMediaCard extends StatelessWidget {
  const _InvalidMediaCard({
    required this.item,
    required this.library,
    required this.isDeleting,
    required this.canDelete,
    required this.onDelete,
  });

  final InvalidMediaDto item;
  final MediaLibraryDto? library;
  final bool isDeleting;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final coverWidth =
        context.appComponentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = context.appComponentTokens.mobileFollowMovieCardHeight;
    final spacing = context.appSpacing;
    final updatedAtText = formatUpdatedAtLabel(item.updatedAt) ?? '更新时间未知';
    final fileSizeText = item.fileSizeBytes > 0
        ? formatFileSize(item.fileSizeBytes)
        : '未知';
    final libraryText = item.libraryName?.trim().isNotEmpty == true
        ? item.libraryName!
        : item.libraryId == null
        ? '媒体库已删除'
        : '媒体库 ${item.libraryId}';

    return AppContentCard(
      title: item.displayTitle,
      headerBottomSpacing: spacing.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaCoverThumbnail(
            url: item.preferredCoverUrl,
            width: coverWidth,
            height: coverHeight,
            fit: item.usesThinCover ? BoxFit.cover : BoxFit.contain,
            imageKey: Key('invalid-media-cover-${item.id}'),
            placeholderKey: Key('invalid-media-cover-placeholder-${item.id}'),
            placeholderBackground: context.appColors.surfaceMuted,
          ),
          SizedBox(width: spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.movieNumber ?? item.displayTitle,
                  key: Key('invalid-media-title-${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.sm),
                AppInfoBlock(label: '媒体库', value: libraryText),
                if (library != null) ...[
                  SizedBox(height: spacing.xs),
                  AppInfoBlock(label: 'Provider', value: library!.providerKey),
                ],
                SizedBox(height: spacing.xs),
                AppInfoBlock(label: '文件大小', value: fileSizeText),
                SizedBox(height: spacing.xs),
                AppInfoBlock(label: '更新时间', value: updatedAtText),
                SizedBox(height: spacing.sm),
                Text(
                  item.fileName,
                  key: Key('invalid-media-file-name-${item.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.lg),
          AppButton(
            key: Key('invalid-media-delete-${item.id}'),
            label: isDeleting ? '删除中' : '删除',
            size: AppButtonSize.small,
            variant: AppButtonVariant.danger,
            isLoading: isDeleting,
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}
