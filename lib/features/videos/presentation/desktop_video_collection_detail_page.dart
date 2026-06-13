import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 视频合集详情页：有序成员列表，支持拖拽重排、移除、单集/全集连播。
class DesktopVideoCollectionDetailPage extends StatefulWidget {
  const DesktopVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  State<DesktopVideoCollectionDetailPage> createState() =>
      _DesktopVideoCollectionDetailPageState();
}

class _DesktopVideoCollectionDetailPageState
    extends State<DesktopVideoCollectionDetailPage> {
  late final VideoCollectionDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoCollectionDetailController(
      collectionId: widget.collectionId,
      collectionsApi: context.read<VideoCollectionsApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 进入播放：携带合集连播上下文（collectionId + 有序视频 id）。
  void _play(int videoId) {
    final playlist = _controller.orderedVideoIds.join(',');
    context.go(
      Uri(
        path: '$desktopVideosPath/$videoId/player',
        queryParameters: <String, String>{
          'collectionId': '${widget.collectionId}',
          'playlist': playlist,
        },
      ).toString(),
    );
  }

  void _playAll() {
    final ids = _controller.orderedVideoIds;
    if (ids.isEmpty) {
      return;
    }
    _play(ids.first);
  }

  Future<void> _removeItem(int itemId, String title) async {
    final ok = await _controller.removeItem(itemId);
    if (!mounted) {
      return;
    }
    showToast(ok ? '已从合集移除' : '移除失败，请稍后重试');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.errorMessage;
          if (error != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppEmptyState(message: error),
                SizedBox(height: context.appSpacing.md),
                AppButton(
                  label: '重试',
                  variant: AppButtonVariant.secondary,
                  onPressed: _controller.load,
                ),
              ],
            );
          }
          final collection = _controller.collection;
          final items = _controller.items;
          return Padding(
            padding: EdgeInsets.all(context.appSpacing.lg),
            child: Column(
              key: const Key('video-collection-detail-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        collection?.name ?? '合集详情',
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s20,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    AppButton(
                      key: const Key('video-collection-play-all-button'),
                      label: '播放全部',
                      variant: AppButtonVariant.primary,
                      onPressed: items.isEmpty ? null : _playAll,
                    ),
                  ],
                ),
                if (collection != null &&
                    collection.description.trim().isNotEmpty) ...[
                  SizedBox(height: context.appSpacing.sm),
                  Text(
                    collection.description,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
                SizedBox(height: context.appSpacing.lg),
                Expanded(
                  child: items.isEmpty
                      ? const AppEmptyState(message: '合集还没有视频，去视频详情页添加吧')
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: items.length,
                          onReorder: _controller.reorder,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CollectionMemberRow(
                              key: ValueKey<int>(item.itemId),
                              index: index,
                              title: item.video.preferredTitle,
                              coverUrl: item.video.coverImage?.bestAvailableUrl,
                              onPlay: () => _play(item.video.id),
                              onOpen: () =>
                                  context.go('$desktopVideosPath/${item.video.id}'),
                              onRemove: () =>
                                  _removeItem(item.itemId, item.video.preferredTitle),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CollectionMemberRow extends StatelessWidget {
  const _CollectionMemberRow({
    super.key,
    required this.index,
    required this.title,
    required this.coverUrl,
    required this.onPlay,
    required this.onOpen,
    required this.onRemove,
  });

  final int index;
  final String title;
  final String? coverUrl;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.sm),
      child: Container(
        padding: EdgeInsets.all(context.appSpacing.sm),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_indicator,
                color: context.appTextPalette.muted,
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            ClipRRect(
              borderRadius: context.appRadius.xsBorder,
              child: SizedBox(
                width: 64,
                height: 40,
                child: coverUrl != null && coverUrl!.isNotEmpty
                    ? MaskedImage(url: coverUrl!, fit: BoxFit.cover)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceMuted,
                        ),
                        child: Icon(
                          Icons.video_library_outlined,
                          size: context.appComponentTokens.iconSizeSm,
                          color: context.appTextPalette.muted,
                        ),
                      ),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: '播放',
              onPressed: onPlay,
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: context.appComponentTokens.iconSizeSm,
              tooltip: '移除',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
