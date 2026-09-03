import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

class DesktopVideoCollectionsPage extends ConsumerWidget {
  const DesktopVideoCollectionsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      unawaited(
        ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    VideoCollectionDto collection,
  ) async {
    final updated = await showVideoCollectionDialog(
      context,
      existing: collection,
    );
    if (updated != null) {
      unawaited(
        ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    VideoCollectionDto collection,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除合集',
      message: '确定删除合集「${collection.name}」吗？合集内的视频不会被删除。',
      danger: true,
      confirmLabel: '删除',
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(videoCollectionsApiProvider).deleteCollection(collection.id);
      await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
      if (context.mounted) {
        showToast('已删除');
      }
    } catch (_) {
      if (context.mounted) {
        showToast('删除失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoCollectionsOverviewProvider);
    final notifier = ref.read(videoCollectionsOverviewProvider.notifier);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        // 页面边距由桌面 shell 的 AppPageInsets.desktopStandard (24px) 统一提供，
        // 此处不再叠加 EdgeInsets.all(spacing.lg)，否则合计 40px 比合集详情等
        // 同类页明显宽（详情页此前已修，这里是漏掉的一处）。
        child: SingleChildScrollView(
          child: Column(
            key: const Key('video-collections-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  AppButton(
                    key: const Key('video-collections-create-button'),
                    label: '新建合集',
                    variant: AppButtonVariant.primary,
                    onPressed: () => _create(context, ref),
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.lg),
              _buildBody(context, ref, async),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<VideoCollectionDto>> async,
  ) {
    if (async.isLoading && async.value == null) {
      final spacing = context.appSpacing;
      return Wrap(
        key: const Key('video-collections-loading'),
        spacing: spacing.md,
        runSpacing: spacing.md,
        children: List<Widget>.generate(
          4,
          (_) => const SizedBox(width: 280, child: CollectionCardSkeleton()),
        ),
      );
    }
    if (async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(
          async.error!,
          fallback: '合集加载失败，请稍后重试',
        ),
      );
    }
    final collections = async.value ?? const <VideoCollectionDto>[];
    if (collections.isEmpty) {
      return const AppEmptyState(message: '暂无合集，点击「新建合集」创建');
    }
    return Wrap(
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        for (final collection in collections)
          SizedBox(
            width: 280,
            child: CollectionCard.video(
              collection: collection,
              onTap:
                  () => context.go(
                    '$desktopVideoCollectionsPath/${collection.id}',
                  ),
              onEdit: () => _edit(context, ref, collection),
              onDelete: () => _delete(context, ref, collection),
            ),
          ),
      ],
    );
  }
}
