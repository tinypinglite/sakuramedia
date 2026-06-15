import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/video_collection_detail_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_mutation_change_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/collections/collection_member_views.dart';

/// 合集详情的成员排布方式：纵向列表或网格（侧重浏览）。
enum _VideoLayout { list, grid }

/// 移动端视频合集详情页：有序成员列表 / 网格 + 改名 / 移除 / 连播。
///
/// 列表复用桌面端同款行物料 [CollectionMemberRow]（关闭悬停与拖序）；网格用竖版海报卡
/// [CollectionMemberCard]（标题压图）。点击成员走动作抽屉（播放 / 移出合集）。
/// 添加成员仍走视频列表的「加入合集」，故此页不设「添加」入口（与桌面对齐）。
class MobileVideoCollectionDetailPage extends StatefulWidget {
  const MobileVideoCollectionDetailPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<MobileVideoCollectionDetailPage> createState() =>
      _MobileVideoCollectionDetailPageState();
}

class _MobileVideoCollectionDetailPageState
    extends State<MobileVideoCollectionDetailPage> {
  late final VideoCollectionDetailController _controller;
  late final VideoMutationChangeNotifier _mutationNotifier;
  _VideoLayout _layout = _VideoLayout.grid;

  void _toggleLayout() {
    setState(() {
      _layout =
          _layout == _VideoLayout.list ? _VideoLayout.grid : _VideoLayout.list;
    });
  }

  @override
  void initState() {
    super.initState();
    _mutationNotifier = context.read<VideoMutationChangeNotifier>();
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.collection == null) {
            return const Center(
              child: SizedBox(
                key: Key('mobile-video-collection-detail-loading'),
                width: 32,
                height: 32,
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_controller.errorMessage != null &&
              _controller.collection == null) {
            return AppEmptyState(message: _controller.errorMessage!);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildBody(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final spacing = context.appSpacing;
    final collection = _controller.collection;
    final items = _controller.items;
    final count = collection?.itemCount ?? items.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection?.name ?? '合集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '$count 个视频',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            AppIconButton(
              key: const Key('mobile-video-collection-layout-toggle'),
              tooltip: _layout == _VideoLayout.list ? '网格视图' : '列表视图',
              onPressed: _toggleLayout,
              icon: Icon(
                _layout == _VideoLayout.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                size: context.appComponentTokens.iconSizeSm,
              ),
            ),
            SizedBox(width: spacing.xs),
            AppTextButton(
              key: const Key('mobile-video-collection-play-all-button'),
              label: '播放',
              size: AppTextButtonSize.small,
              emphasis: AppTextButtonEmphasis.accent,
              onPressed: () => _playFrom(0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '合集还没有视频，去视频列表用「加入合集」添加吧');
    }
    return _layout == _VideoLayout.grid
        ? _buildGrid(context)
        : _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final spacing = context.appSpacing;
    final items = _controller.items;
    return ListView.separated(
      key: const Key('mobile-video-collection-detail-list'),
      padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
      itemCount: items.length,
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return CollectionMemberRow(
          key: ValueKey<int>(item.itemId),
          index: index,
          coverUrl: item.video.coverImage?.bestAvailableUrl,
          coverWidth: 64,
          coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
          coverFit: BoxFit.contain,
          title: item.video.preferredTitle,
          subtitle: _subtitleFor(item.video),
          placeholderIcon: Icons.video_library_outlined,
          titleMaxLines: 2,
          // 移动端无悬停、不支持拖序，关闭手柄与 hover 显隐逻辑。
          isHovered: false,
          reorderable: false,
          onTap: () => _openSheet(index, item.video),
          menuKey: Key('mobile-video-collection-menu-${item.itemId}'),
          dragHandleKey: Key('mobile-video-reorder-handle-${item.itemId}'),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    final spacing = context.appSpacing;
    final items = _controller.items;
    return GridView.builder(
      key: const Key('mobile-video-collection-detail-grid'),
      padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        childAspectRatio: context.appComponentTokens.movieCardAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CollectionMemberCard(
          key: ValueKey<int>(item.itemId),
          coverUrl: item.video.coverImage?.bestAvailableUrl,
          coverAspectRatio: context.appComponentTokens.movieCardAspectRatio,
          title: item.video.preferredTitle,
          subtitle: _subtitleFor(item.video),
          placeholderIcon: Icons.video_library_outlined,
          titleMaxLines: 2,
          overlayCaption: true,
          onTap: () => _openSheet(index, item.video),
          menuKey: Key('mobile-video-collection-grid-menu-${item.itemId}'),
        );
      },
    );
  }

  String? _subtitleFor(VideoItemListItemDto video) {
    if (video.durationSeconds <= 0) {
      return null;
    }
    return formatMediaTimecode(video.durationSeconds);
  }

  void _openSheet(int index, VideoItemListItemDto video) {
    final itemId = _controller.items[index].itemId;
    showMobileVideoActionsSheet(
      context,
      video: video,
      onPlay: () => _playFrom(index),
      onRemoveFromCollection: () => _removeItem(itemId, video.id),
    );
  }

  void _playFrom(int index) {
    MobileVideoCollectionPlayRouteData(
      collectionId: widget.collectionId,
      startIndex: index,
      // 移动端详情页按手动顺序展示（sortExpression 为 null），连播顺序与之一致。
      sort: _controller.sortExpression,
    ).push(context);
  }

  Future<void> _removeItem(int itemId, int videoId) async {
    final error = await _controller.removeItem(itemId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _mutationNotifier.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(error ?? '已从合集移除');
  }
}
