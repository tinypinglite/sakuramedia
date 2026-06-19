import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collections_overview_controller.dart';
import 'package:sakuramedia/features/clip_collections/presentation/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/clips/presentation/mobile_clip_confirm_drawer.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';

/// 移动端切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除（编辑与确认走底部抽屉）。
class MobileClipCollectionsPage extends StatefulWidget {
  const MobileClipCollectionsPage({super.key});

  @override
  State<MobileClipCollectionsPage> createState() =>
      _MobileClipCollectionsPageState();
}

class _MobileClipCollectionsPageState extends State<MobileClipCollectionsPage> {
  late final ClipCollectionsOverviewController _controller;
  late final ClipMutationChangeNotifier _mutationNotifier;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<ClipCollectionsApi>();
    _mutationNotifier = context.read<ClipMutationChangeNotifier>();
    _controller = ClipCollectionsOverviewController(
      fetchCollections: api.getCollections,
    )..load();
    _mutationNotifier.addListener(_onMutation);
  }

  @override
  void dispose() {
    _mutationNotifier.removeListener(_onMutation);
    _controller.dispose();
    super.dispose();
  }

  /// 详情页（压在本页之上）增删 / 改名后，合集卡的封面、计数、名称可能变化；
  /// 用微任务合并一轮内的多次信号成一次整列表刷新。
  void _onMutation() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-clip-collections-page'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(child: _buildBody(context)),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-clip-collections-create-button'),
                label: '新建合集',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _createCollection,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(
            child: SizedBox(
              key: Key('mobile-clip-collections-loading'),
              width: 32,
              height: 32,
              child: CircularProgressIndicator(),
            ),
          );
        }
        final spacing = context.appSpacing;
        final collections = _controller.collections;
        return AppAdaptiveRefreshScrollView(
          key: const Key('mobile-clip-collections-scroll'),
          onRefresh: _controller.refresh,
          slivers: <Widget>[
            if (_controller.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(message: _controller.errorMessage!),
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
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: spacing.md,
                    crossAxisSpacing: spacing.sm,
                    // [CollectionCoverCard] = 16:9 封面 + 标题(s14, 单行) + sm 内边距,
                    // 实际内容高度约 (0.5625×W + 34)px。aspectRatio 1.25 让 cell 高度刚好
                    // 贴合内容，对齐桌面合集卡的紧凑观感（此前 1.05 会留 ~30px 底部空白）。
                    childAspectRatio: 1.25,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final collection = collections[index];
                    return CollectionCard.clip(
                      key: Key(
                        'mobile-clip-collection-card-${collection.id}',
                      ),
                      collection: collection,
                      onTap:
                          () =>
                              MobileClipCollectionDetailRouteData(
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
      },
    );
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || created == null) {
      return;
    }
    _controller.insertCollection(created);
    showToast('已创建合集');
  }

  Future<void> _editCollection(ClipCollectionDto collection) async {
    final updated = await showEditClipCollectionDialog(
      context,
      collection: collection,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.replaceCollection(updated);
    showToast('已保存');
  }

  Future<void> _deleteCollection(ClipCollectionDto collection) async {
    final name =
        collection.name.trim().isEmpty ? '该合集' : '“${collection.name.trim()}”';
    final confirmed = await showMobileClipConfirmDrawer(
      context,
      title: '删除合集',
      message: '确认删除$name？合集内的切片不会被删除。',
      confirmLabel: '删除',
      drawerKey: const Key('mobile-clip-collection-delete-drawer'),
      confirmButtonKey: const Key('mobile-clip-collection-delete-confirm-button'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await context.read<ClipCollectionsApi>().deleteCollection(
        collectionId: collection.id,
      );
      _controller.removeCollection(collection.id);
      if (mounted) {
        showToast('已删除合集');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }
}
