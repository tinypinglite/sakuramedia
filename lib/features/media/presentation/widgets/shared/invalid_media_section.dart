import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
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

/// 「媒体维护」（失效媒体巡检）主体 section：说明头 + 卡片列表 + load-more。
///
/// 数据源：`invalidMediaProvider` + `mediaLibrariesProvider`。复查/删除/确认弹窗内嵌，
/// 页面只负责挂 scroll listener 与 active 懒加载。
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

    return AppFilterTotalHeader(
      leading: Text(
        '巡检标记为失效的媒体库内容会出现在这里。你可以复查媒体是否恢复，或清理已经确认不可用的记录。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      ),
      totalText: '共 ${headerState.total} 条失效媒体',
      totalKey: const Key('invalid-media-total-text'),
      trailing: AppIconButton(
        key: const Key('invalid-media-refresh-button'),
        tooltip: headerState.isInitialLoading ? '刷新中' : '刷新',
        icon: const Icon(Icons.refresh_rounded),
        onPressed:
            headerState.isInitialLoading
                ? null
                : () async {
                  final message =
                      await ref.read(invalidMediaProvider.notifier).refresh();
                  if (message != null) showToast(message);
                },
      ),
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
      onReload:
          () => unawaited(ref.read(invalidMediaProvider.notifier).reload()),
      onLoadMore:
          () => unawaited(ref.read(invalidMediaProvider.notifier).loadMore()),
      itemBuilder: (context, item, _) => _InvalidMediaRowConsumer(item: item),
    );
  }
}

class _InvalidMediaRowConsumer extends ConsumerWidget {
  const _InvalidMediaRowConsumer({required this.item});

  final InvalidMediaDto item;

  Future<void> _handleCheck(
    WidgetRef ref,
    BuildContext context,
    InvalidMediaDto item,
  ) async {
    try {
      final result = await ref
          .read(invalidMediaProvider.notifier)
          .checkValidity(mediaId: item.id);
      if (!context.mounted) return;
      showToast(result.validAfter ? '媒体已恢复' : '媒体仍不可用，已开放删除');
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '媒体有效性复查失败'));
      }
    }
  }

  Future<void> _handleDelete(
    WidgetRef ref,
    BuildContext context,
    InvalidMediaDto item,
    MediaStorageDescriptor storage,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除失效媒体',
      message:
          storage.isCloud115
              ? '确认删除"${item.movieNumber}"的这条失效媒体记录和 115 网盘文件？网盘文件将进入 115 回收站。请确认刚才复查后媒体仍不可用。'
              : storage.isLocal
              ? '确认删除"${item.movieNumber}"的这条失效媒体记录和本地媒体文件？该操作不可恢复。请确认刚才复查后媒体仍不可用。'
              : '确认删除"${item.movieNumber}"的这条失效媒体记录及对应媒体文件？该操作可能无法恢复。请确认刚才复查后媒体仍不可用。',
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
        (asyncState) => (
          checkingMediaId: asyncState.value?.checkingMediaId,
          deletingMediaId: asyncState.value?.deletingMediaId,
          canDelete: asyncState.value?.canDeleteMedia(item.id) ?? false,
        ),
      ),
    );
    final storageDescriptors = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.storageDescriptors ??
            const <int, MediaStorageDescriptor>{},
      ),
    );
    final isCheckingAny = actionState.checkingMediaId != null;
    final isDeletingAny = actionState.deletingMediaId != null;

    return _InvalidMediaCard(
      item: item,
      storage: resolveMediaStorageDescriptor(
        item.libraryId,
        storageDescriptors,
      ),
      isChecking: actionState.checkingMediaId == item.id,
      isDeleting: actionState.deletingMediaId == item.id,
      canCheck: !isCheckingAny && !isDeletingAny,
      canDelete: actionState.canDelete && !isCheckingAny && !isDeletingAny,
      onCheck: () => unawaited(_handleCheck(ref, context, item)),
      onDelete:
          (storage) => unawaited(_handleDelete(ref, context, item, storage)),
    );
  }
}

class _InvalidMediaCard extends StatelessWidget {
  const _InvalidMediaCard({
    required this.item,
    required this.storage,
    required this.isChecking,
    required this.isDeleting,
    required this.canCheck,
    required this.canDelete,
    required this.onCheck,
    required this.onDelete,
  });

  final InvalidMediaDto item;
  final MediaStorageDescriptor storage;
  final bool isChecking;
  final bool isDeleting;
  final bool canCheck;
  final bool canDelete;
  final VoidCallback onCheck;
  final ValueChanged<MediaStorageDescriptor> onDelete;

  @override
  Widget build(BuildContext context) {
    final coverWidth =
        context.appComponentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = context.appComponentTokens.mobileFollowMovieCardHeight;
    final spacing = context.appSpacing;

    final updatedAtText = formatUpdatedAtLabel(item.updatedAt) ?? '更新时间未知';
    final fileSizeText =
        item.fileSizeBytes > 0 ? formatFileSize(item.fileSizeBytes) : '未知';

    return AppContentCard(
      title: item.movieNumber,
      headerBottomSpacing: spacing.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaCoverThumbnail(
            url: item.preferredCoverUrl,
            width: coverWidth,
            height: coverHeight,
            fit: item.usesThinCover ? BoxFit.cover : BoxFit.contain,
            imageKey: Key('invalid-media-cover-${item.movieNumber}'),
            placeholderKey: Key(
              'invalid-media-cover-placeholder-${item.movieNumber}',
            ),
            placeholderBackground: context.appColors.surfaceMuted,
          ),
          SizedBox(width: spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
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
                AppInfoBlock(label: '媒体库', value: _libraryText()),
                SizedBox(height: spacing.xs),
                AppInfoBlock(label: '文件大小', value: fileSizeText),
                SizedBox(height: spacing.xs),
                AppInfoBlock(label: '更新时间', value: updatedAtText),
                SizedBox(height: spacing.sm),
                Text(
                  storage.formatLocationText(item.path),
                  key: Key('invalid-media-path-${item.id}'),
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
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              AppButton(
                key: Key('invalid-media-check-${item.id}'),
                label: isChecking ? '复查中' : '复查',
                size: AppButtonSize.small,
                isLoading: isChecking,
                onPressed: canCheck ? onCheck : null,
              ),
              AppButton(
                key: Key('invalid-media-delete-${item.id}'),
                label: isDeleting ? '删除中' : (canDelete ? '删除' : '先复查'),
                size: AppButtonSize.small,
                variant: AppButtonVariant.danger,
                isLoading: isDeleting,
                onPressed: canDelete ? () => onDelete(storage) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _libraryText() {
    final name = item.libraryName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return item.libraryId == null ? '媒体库已删除' : '媒体库 ${item.libraryId}';
  }
}
