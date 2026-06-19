import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/add_to_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collections_overview_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/clips_api.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clips_overview_controller.dart';
import 'package:sakuramedia/features/clips/presentation/rename_clip_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';
import 'package:sakuramedia/widgets/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/clips/clip_player_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';

/// 切片首页：上方「我的合集」横滑区 + 下方「全部切片」网格（悬停预览、加入合集）。
class DesktopClipsPage extends StatefulWidget {
  const DesktopClipsPage({super.key});

  @override
  State<DesktopClipsPage> createState() => _DesktopClipsPageState();
}

class _DesktopClipsPageState extends State<DesktopClipsPage> {
  late final ClipsOverviewController _clipsController;
  late final ClipCollectionsOverviewController _collectionsController;
  late final ClipMutationChangeNotifier _mutationNotifier;
  final ScrollController _scrollController = ScrollController();
  bool _railRefreshScheduled = false;

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_clipsController, _collectionsController]);

  @override
  void initState() {
    super.initState();
    final clipsApi = context.read<ClipsApi>();
    final collectionsApi = context.read<ClipCollectionsApi>();
    _mutationNotifier = context.read<ClipMutationChangeNotifier>();
    _clipsController = ClipsOverviewController(
      fetchClips:
          ({
            int page = 1,
            int pageSize = 24,
            String sort = 'created_at:desc',
          }) =>
              clipsApi.getMyClips(page: page, pageSize: pageSize, sort: sort),
    )..load();
    _collectionsController = ClipCollectionsOverviewController(
      fetchCollections: collectionsApi.getCollections,
    )..load();
    _scrollController.addListener(_onScroll);
    _mutationNotifier.addListener(_onMutation);
  }

  @override
  void dispose() {
    _mutationNotifier.removeListener(_onMutation);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _clipsController.dispose();
    _collectionsController.dispose();
    super.dispose();
  }

  /// 切片删除 / 合集成员变化都可能改变合集横滑区的封面与计数；用微任务把一轮内
  /// 的多次信号（如详情页批量改动）合并成一次刷新，避免 N 次请求。切片本身被删除
  /// 时再从「全部切片」网格精准移除。
  void _onMutation() {
    final change = _mutationNotifier.lastChange;
    if (change == null) {
      return;
    }
    if (change.kind == ClipMutationKind.deleted && change.clipId != null) {
      _clipsController.removeClip(change.clipId!);
    }
    if (_railRefreshScheduled) {
      return;
    }
    _railRefreshScheduled = true;
    scheduleMicrotask(() {
      _railRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      _collectionsController.refresh();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _clipsController.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: _pageListenable,
        builder: (context, _) {
          // 仅首屏（尚无任何切片）才整页 spinner；切换排序等重载时保留页面骨架，
          // 让合集区与标题栏不被销毁重建，旧列表沿用到新数据返回。
          if (_clipsController.isLoading && _clipsController.clips.isEmpty) {
            return const Center(
              child: SizedBox(
                key: Key('clips-page-loading'),
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_clipsController.errorMessage != null) {
            return AppEmptyState(message: _clipsController.errorMessage!);
          }
          return CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildCollectionsSection(context)),
              SliverToBoxAdapter(child: _buildClipsHeader(context)),
              _buildClipsSliver(context),
              SliverToBoxAdapter(child: _buildFooter(context)),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 合集区

  Widget _buildCollectionsSection(BuildContext context) {
    final spacing = context.appSpacing;
    final collections = _collectionsController.collections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '我的合集',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            const Spacer(),
            AppTextButton(
              key: const Key('clips-create-collection-button'),
              label: '新建',
              size: AppTextButtonSize.small,
              emphasis: AppTextButtonEmphasis.accent,
              onPressed: _createCollection,
            ),
            if (collections.isNotEmpty) ...[
              SizedBox(width: spacing.xs),
              AppTextButton(
                key: const Key('clips-view-all-collections-button'),
                label: '查看全部',
                size: AppTextButtonSize.small,
                emphasis: AppTextButtonEmphasis.accent,
                onPressed: _viewAllCollections,
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.sm),
        _buildCollectionsRow(context, collections),
        SizedBox(height: spacing.lg),
      ],
    );
  }

  Widget _buildCollectionsRow(
    BuildContext context,
    List<ClipCollectionDto> collections,
  ) {
    if (_collectionsController.errorMessage != null) {
      return _HintBox(message: _collectionsController.errorMessage!);
    }
    if (_collectionsController.isLoading && collections.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (collections.isEmpty) {
      return const _HintBox(message: '还没有合集，点「新建」把喜欢的切片攒成一个连播合集吧');
    }
    final spacing = context.appSpacing;
    return SizedBox(
      height: 172,
      child: ListView.separated(
        key: const Key('clips-collections-row'),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing.md),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 210,
            child: CollectionCard.clip(
              key: Key('clip-collection-card-${collection.id}'),
              collection: collection,
              onTap:
                  () => context.pushDesktopClipCollectionDetail(
                    collectionId: collection.id,
                  ),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- 切片区

  Widget _buildClipsHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.sm),
      child: Row(
        children: [
          Text(
            '全部切片',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          const Spacer(),
          // 与「时刻」页保持一致：最新/最早并排，选中高亮。
          _buildSortAction(
            context,
            actionKey: const Key('clips-sort-latest'),
            label: '最新',
            sort: 'created_at:desc',
          ),
          SizedBox(width: context.appSpacing.sm),
          _buildSortAction(
            context,
            actionKey: const Key('clips-sort-earliest'),
            label: '最早',
            sort: 'created_at:asc',
          ),
        ],
      ),
    );
  }

  Widget _buildSortAction(
    BuildContext context, {
    required Key actionKey,
    required String label,
    required String sort,
  }) {
    return AppTextButton(
      key: actionKey,
      label: label,
      size: AppTextButtonSize.xSmall,
      isSelected: _clipsController.sort == sort,
      onPressed: () => _clipsController.setSort(sort),
    );
  }

  Widget _buildClipsSliver(BuildContext context) {
    final clips = _clipsController.clips;
    if (clips.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: AppEmptyState(message: '还没有切片，去播放器圈选生成吧'),
        ),
      );
    }
    final spacing = context.appSpacing;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _resolveColumnCount(
          constraints.crossAxisExtent,
          spacing.md,
        );
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 10,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final clip = clips[index];
            final movieNumber = clip.movieNumber;
            return ClipGridCard(
              key: Key('clip-grid-card-${clip.clipId}'),
              clip: clip,
              onPlay: () => _playClip(clip),
              onRename: () => _renameClip(clip),
              onDelete: () => _deleteClip(clip),
              onAddToCollection: () => _addToCollection(clip),
              onOpenMovie:
                  movieNumber != null && movieNumber.isNotEmpty
                      ? () => _openMovie(movieNumber)
                      : null,
            );
          }, childCount: clips.length),
        );
      },
    );
  }

  int _resolveColumnCount(double width, double spacing) {
    final columns = ((width + spacing) / (280 + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }

  Widget _buildFooter(BuildContext context) {
    if (_clipsController.loadMoreErrorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: Center(
          child: AppButton(
            key: const Key('clips-load-more-retry'),
            label: '加载更多失败，点击重试',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: _clipsController.loadMore,
          ),
        ),
      );
    }
    if (_clipsController.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox(height: context.appSpacing.lg);
  }

  // ----------------------------------------------------------- 动作

  void _playClip(MediaClipDto clip) {
    showClipPlayerDialog(context, streamUrl: clip.streamUrl, title: clip.title);
  }

  void _openMovie(String movieNumber) {
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopClipsPath,
    );
  }

  Future<void> _renameClip(MediaClipDto clip) async {
    final newTitle = await showRenameClipDialog(
      context,
      initialTitle: clip.title,
    );
    if (!mounted || newTitle == null) {
      return;
    }
    try {
      final updated = await context.read<ClipsApi>().updateClipTitle(
        clipId: clip.clipId,
        title: newTitle,
      );
      _clipsController.replaceClip(updated);
      if (mounted) {
        showToast('已重命名');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '重命名失败，请重试'));
    }
  }

  Future<void> _deleteClip(MediaClipDto clip) async {
    final title = clip.title.trim().isEmpty ? '该切片' : '“${clip.title.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除切片',
      message: '确认删除$title？切片文件会被一并删除，该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
      confirmKey: const Key('clip-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await context.read<ClipsApi>().deleteClip(clipId: clip.clipId);
      // 广播删除信号：本页监听后从网格精准移除，并刷新合集横滑区（封面 / 计数可能变化）。
      _mutationNotifier.reportDeleted(clip.clipId);
      if (mounted) {
        showToast('已删除切片');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }

  Future<void> _addToCollection(MediaClipDto clip) async {
    await showAddToClipCollectionDialog(context, clipId: clip.clipId);
    if (!mounted) {
      return;
    }
    // 合集归属可能变化（含新建）：广播信号，由本页监听统一刷新合集横滑区。
    _mutationNotifier.reportCollectionMembershipChanged(clipId: clip.clipId);
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(context);
    if (!mounted || created == null) {
      return;
    }
    _collectionsController.insertCollection(created);
    showToast('已创建合集');
  }

  Future<void> _viewAllCollections() async {
    await context.pushDesktopClipCollections();
    if (!mounted) {
      return;
    }
    // 全部合集页内可能重命名/删除合集，返回后刷新首页合集横滑区。
    await _collectionsController.refresh();
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}
