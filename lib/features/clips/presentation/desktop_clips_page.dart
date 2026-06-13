import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
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
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/clip_collections/clip_collection_card.dart';
import 'package:sakuramedia/widgets/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/clips/clip_player_dialog.dart';

/// 切片首页：上方「我的合集」横滑区 + 下方「全部切片」网格（悬停预览、加入合集）。
class DesktopClipsPage extends StatefulWidget {
  const DesktopClipsPage({super.key});

  @override
  State<DesktopClipsPage> createState() => _DesktopClipsPageState();
}

class _DesktopClipsPageState extends State<DesktopClipsPage> {
  late final ClipsOverviewController _clipsController;
  late final ClipCollectionsOverviewController _collectionsController;
  final ScrollController _scrollController = ScrollController();

  Listenable get _pageListenable =>
      Listenable.merge(<Listenable>[_clipsController, _collectionsController]);

  @override
  void initState() {
    super.initState();
    final clipsApi = context.read<ClipsApi>();
    final collectionsApi = context.read<ClipCollectionsApi>();
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
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _clipsController.dispose();
    _collectionsController.dispose();
    super.dispose();
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
                onPressed: () => context.pushDesktopClipCollections(),
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
            child: ClipCollectionCard(
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
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        childAspectRatio: 1.15,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final clip = clips[index];
        return ClipGridCard(
          key: Key('clip-grid-card-${clip.clipId}'),
          clip: clip,
          onPlay: () => _playClip(clip),
          onRename: () => _renameClip(clip),
          onDelete: () => _deleteClip(clip),
          onAddToCollection: () => _addToCollection(clip),
          loadPreviewFrames:
              () => context
                  .read<ClipsApi>()
                  .getClipDetail(clipId: clip.clipId)
                  .then((detail) => detail.previewFrames),
        );
      }, childCount: clips.length),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteClipConfirmDialog(clip: clip),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await context.read<ClipsApi>().deleteClip(clipId: clip.clipId);
      _clipsController.removeClip(clip.clipId);
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
    // 合集归属可能变化（含新建），统一刷新合集区。
    await _collectionsController.refresh();
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(context);
    if (!mounted || created == null) {
      return;
    }
    _collectionsController.insertCollection(created);
    showToast('已创建合集');
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

class _DeleteClipConfirmDialog extends StatelessWidget {
  const _DeleteClipConfirmDialog({required this.clip});

  final MediaClipDto clip;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final title = clip.title.trim().isEmpty ? '该切片' : '“${clip.title.trim()}”';
    return AlertDialog(
      backgroundColor: context.appColors.surfaceCard,
      actionsOverflowButtonSpacing: spacing.sm,
      title: Text(
        '删除切片',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s16,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      content: Text(
        '确认删除$title？切片文件会被一并删除，该操作不可恢复。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
      actions: [
        AppButton(
          label: '取消',
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('clip-delete-confirm-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
