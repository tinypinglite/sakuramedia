import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/clip_collection_delete_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除。
class DesktopClipCollectionsPage extends ConsumerStatefulWidget {
  const DesktopClipCollectionsPage({super.key});

  @override
  ConsumerState<DesktopClipCollectionsPage> createState() =>
      _DesktopClipCollectionsPageState();
}

class _DesktopClipCollectionsPageState
    extends ConsumerState<DesktopClipCollectionsPage> {
  bool _refreshScheduled = false;

  /// 详情页（压在本页之上）增删 / 拖序 / 改名后，合集卡的封面、计数、名称可能变化；
  /// 用微任务合并一轮内的多次信号成一次整列表刷新。
  void _onMutation(ClipMutationChange _) {
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
        ref.read(clipCollectionsOverviewProvider.notifier).refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClipMutationChange>>(
      clipMutationEventsProvider,
      (previous, next) {
        final change = next.value;
        if (change != null) {
          _onMutation(change);
        }
      },
    );

    final async = ref.watch(clipCollectionsOverviewProvider);
    final notifier = ref.read(clipCollectionsOverviewProvider.notifier);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: Column(
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
                  onPressed: _createCollection,
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.lg),
            Expanded(child: _buildBody(context, async)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<ClipCollectionDto>> async,
  ) {
    if (async.isLoading && async.value == null) {
      return const Center(
        child: SizedBox(
          key: Key('clip-collections-loading'),
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(
          async.error!,
          fallback: '合集暂时无法加载，请稍后重试',
        ),
      );
    }
    final collections = async.value ?? const <ClipCollectionDto>[];
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
    ref.read(clipCollectionsOverviewProvider.notifier).insertCollection(created);
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
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .replaceCollection(updated);
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
      await ref
          .read(clipCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(clipCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      if (mounted) {
        showToast('已删除合集');
      }
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }
}
