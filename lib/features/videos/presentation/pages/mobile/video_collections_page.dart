import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_confirm_drawer.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 移动端视频合集列表页：全部合集网格 + 新建 / 编辑 / 删除（编辑与确认走底部抽屉）。
class MobileVideoCollectionsPage extends ConsumerStatefulWidget {
  const MobileVideoCollectionsPage({super.key});

  @override
  ConsumerState<MobileVideoCollectionsPage> createState() =>
      _MobileVideoCollectionsPageState();
}

class _MobileVideoCollectionsPageState
    extends ConsumerState<MobileVideoCollectionsPage> {
  bool _refreshScheduled = false;

  /// 详情页（压在本页之上）增删 / 改名后，合集卡的封面、计数、名称可能变化；
  /// 用微任务合并一轮内的多次信号成一次整列表刷新。
  void _onMutation(VideoMutationChange _) {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<VideoMutationChange>>(
      videoMutationEventsProvider,
      (previous, next) {
        final change = next.value;
        if (change != null) {
          _onMutation(change);
        }
      },
    );

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final async = ref.watch(videoCollectionsOverviewProvider);

    return ColoredBox(
      key: const Key('mobile-video-collections-page'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(child: _buildBody(context, async)),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('mobile-video-collections-create-button'),
                  label: '新建合集',
                  variant: AppButtonVariant.primary,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _createCollection,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> async,
  ) {
    if (async.isLoading && async.value == null) {
      return const AppMobileSkeletonList(
        key: Key('mobile-video-collections-loading'),
      );
    }
    final spacing = context.appSpacing;
    final collections = async.value ?? const <VideoCollectionDto>[];
    return AppAdaptiveRefreshScrollView(
      key: const Key('mobile-video-collections-scroll'),
      onRefresh:
          ref.read(videoCollectionsOverviewProvider.notifier).refresh,
      slivers: <Widget>[
        if (async.hasError && collections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              message: apiErrorMessage(
                async.error!,
                fallback: '合集加载失败，请稍后重试',
              ),
            ),
          )
        else if (collections.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(message: '还没有合集，点下方「新建合集」开始吧'),
          )
        else
          SliverPadding(
            // 横向缩进由 shell 8px body padding 统一提供，此处只补上下留白。
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: spacing.md,
                crossAxisSpacing: spacing.sm,
                // [CollectionCoverCard] = 16:9 封面 + 标题(s14, 单行) + sm 内边距,
                // 实际内容高度约 (0.5625×W + 34)px。aspectRatio 1.25 让 cell 高度刚好
                // 贴合内容，对齐桌面合集卡的紧凑观感（此前 0.78 会留 ~80px 底部空白）。
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final collection = collections[index];
                return CollectionCard.video(
                  key: Key('mobile-video-collection-card-${collection.id}'),
                  collection: collection,
                  onTap:
                      () => MobileVideoCollectionDetailRouteData(
                        collectionId: collection.id,
                      ).push(context),
                  onEdit: () => _editCollection(collection),
                  onDelete: () => _deleteCollection(collection),
                );
              }, childCount: collections.length),
            ),
          ),
      ],
    );
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: VideoCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || created == null) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (mounted) {
      showToast('已创建合集');
    }
  }

  Future<void> _editCollection(VideoCollectionDto collection) async {
    final updated = await showVideoCollectionDialog(
      context,
      existing: collection,
      presentation: VideoCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || updated == null) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (mounted) {
      showToast('已保存');
    }
  }

  Future<void> _deleteCollection(VideoCollectionDto collection) async {
    final name =
        collection.name.trim().isEmpty ? '该合集' : '“${collection.name.trim()}”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除合集',
      message: '确认删除$name？合集内的视频不会被删除。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-video-collection-delete-drawer'),
      confirmButtonKey: const Key(
        'mobile-video-collection-delete-confirm-button',
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .deleteCollection(collection.id);
      await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
      if (mounted) {
        showToast('已删除合集');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }
}
