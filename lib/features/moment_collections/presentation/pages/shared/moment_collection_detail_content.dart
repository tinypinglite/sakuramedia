import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_detail_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';

class MomentCollectionDetailContent extends ConsumerWidget {
  const MomentCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.isMobile,
  });

  final int collectionId;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(
      momentCollectionDetailProvider(collectionId).notifier,
    );
    final async = ref.watch(momentCollectionDetailProvider(collectionId));
    if (async.isLoading && async.value == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(async.error!, fallback: '合集详情加载失败，请稍后重试'),
        retryKey: const Key('moment-collection-detail-retry-button'),
        onRetry: () => ref
            .read(momentCollectionDetailProvider(collectionId).notifier)
            .refresh(),
      );
    }
    final state = async.value;
    if (state == null) return const SizedBox.shrink();
    final collection = state.collection;
    return ColoredBox(
      color: isMobile
          ? context.appColors.surfaceCard
          : context.appColors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s18,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (collection.description.isNotEmpty) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        collection.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppIconButton(
                tooltip: '编辑合集',
                icon: const Icon(Icons.edit_outlined),
                onPressed: notifier.isMutating
                    ? null
                    : () => _edit(context, ref, collection),
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          Text(
            '${state.points.length} 个时刻 · 拖动右侧把手调整顺序',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.tertiary,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          Expanded(child: _buildPoints(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildPoints(
    BuildContext context,
    WidgetRef ref,
    MomentCollectionDetailState state,
  ) {
    final notifier = ref.read(
      momentCollectionDetailProvider(collectionId).notifier,
    );
    if (state.points.isEmpty) {
      return const AppEmptyState(message: '合集还没有时刻，去“时刻”页面添加吧');
    }
    return ReorderableListView.builder(
      key: const Key('moment-collection-detail-list'),
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      itemCount: state.points.length,
      onReorder: (oldIndex, newIndex) async {
        if (notifier.isMutating) return;
        try {
          await notifier.reorder(oldIndex, newIndex);
          if (context.mounted) {
            ref
                .read(momentCollectionMutationEventsProvider.notifier)
                .reportChanged(collectionId);
          }
        } catch (error) {
          showToast(apiErrorMessage(error, fallback: '排序保存失败，请重试'));
        }
      },
      itemBuilder: (context, index) {
        final point = state.points[index];
        final item = point.toMomentListItem();
        return _MomentCollectionPointRow(
          key: ValueKey<int>(point.pointId),
          item: item,
          index: index,
          onTap: () => _preview(context, item),
          onRemove: notifier.isMutating
              ? null
              : () => _remove(context, ref, point.pointId),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MomentCollectionDto collection,
  ) async {
    final updated = await showMomentCollectionEditor(
      context,
      collection: collection,
      presentation: isMobile
          ? MomentCollectionEditPresentation.bottomDrawer
          : MomentCollectionEditPresentation.dialog,
    );
    if (updated != null) {
      ref
          .read(momentCollectionDetailProvider(collectionId).notifier)
          .replaceCollection(updated);
      ref
          .read(momentCollectionMutationEventsProvider.notifier)
          .reportChanged(collectionId);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, int pointId) async {
    try {
      await ref
          .read(momentCollectionDetailProvider(collectionId).notifier)
          .removePoint(pointId);
      if (context.mounted) {
        ref
            .read(momentCollectionMutationEventsProvider.notifier)
            .reportChanged(collectionId);
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '移出合集失败，请重试'));
    }
  }

  Future<void> _preview(BuildContext context, MomentListItem item) async {
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: MediaPreviewPresentation.auto,
    );
    if (!context.mounted || action != MediaPreviewAction.play) return;
    if (item.isVideo) {
      await showVideoQuickPlayDialog(
        context,
        videoId: item.videoItemId!,
        title: item.displayLabel,
      );
      return;
    }
    final movieNumber = item.movieNumber;
    if (movieNumber != null && movieNumber.isNotEmpty) {
      await launchMoviePlayback(
        context,
        movieNumber: movieNumber,
        mediaId: item.mediaId,
        positionSeconds: item.offsetSeconds,
      );
    }
  }
}

class _MomentCollectionPointRow extends StatelessWidget {
  const _MomentCollectionPointRow({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onRemove,
  });

  final MomentListItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Material(
      color: context.appColors.surfaceCard,
      borderRadius: context.appRadius.smBorder,
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: context.appRadius.smBorder),
        leading: ClipRRect(
          borderRadius: context.appRadius.xsBorder,
          child: SizedBox(
            width: 72,
            height: 42,
            child: MaskedImage(
              url: item.image?.bestAvailableUrl ?? '',
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          item.displayLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(formatMediaTimecode(item.offsetSeconds)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '移出合集',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(left: spacing.xs),
                child: const Icon(Icons.drag_handle_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
