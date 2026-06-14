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
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/clip_collections/clip_collection_delete_dialog.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';

/// 切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除。
class DesktopClipCollectionsPage extends StatefulWidget {
  const DesktopClipCollectionsPage({super.key});

  @override
  State<DesktopClipCollectionsPage> createState() =>
      _DesktopClipCollectionsPageState();
}

class _DesktopClipCollectionsPageState
    extends State<DesktopClipCollectionsPage> {
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

  /// 详情页（压在本页之上）增删 / 拖序 / 改名后，合集卡的封面、计数、名称可能变化；
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
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '切片合集',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  const Spacer(),
                  AppTextButton(
                    key: const Key('clip-collections-create-button'),
                    label: '新建合集',
                    size: AppTextButtonSize.small,
                    emphasis: AppTextButtonEmphasis.accent,
                    onPressed: _createCollection,
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.lg),
              Expanded(child: _buildBody(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(
        child: SizedBox(
          key: Key('clip-collections-loading'),
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_controller.errorMessage != null) {
      return AppEmptyState(message: _controller.errorMessage!);
    }
    final collections = _controller.collections;
    if (collections.isEmpty) {
      return const AppEmptyState(message: '还没有合集，点右上角「新建合集」开始吧');
    }

    final spacing = context.appSpacing;
    return GridView.builder(
      key: const Key('clip-collections-grid'),
      padding: EdgeInsets.only(bottom: spacing.lg),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return CollectionCard.clip(
          key: Key('clip-collection-card-${collection.id}'),
          collection: collection,
          onTap:
              () => context.pushDesktopClipCollectionDetail(
                collectionId: collection.id,
              ),
          onEdit: () => _editCollection(collection),
          onDelete: () => _deleteCollection(collection),
        );
      },
    );
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(context);
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
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.replaceCollection(updated);
    showToast('已保存');
  }

  Future<void> _deleteCollection(ClipCollectionDto collection) async {
    final confirmed = await showClipCollectionDeleteDialog(
      context,
      collection: collection,
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
