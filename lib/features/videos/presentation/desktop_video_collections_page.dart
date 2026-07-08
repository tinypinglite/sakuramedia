import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/collections/video_collections_overview_controller.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/collections/collection_card.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';

class DesktopVideoCollectionsPage extends StatefulWidget {
  const DesktopVideoCollectionsPage({super.key});

  @override
  State<DesktopVideoCollectionsPage> createState() =>
      _DesktopVideoCollectionsPageState();
}

class _DesktopVideoCollectionsPageState
    extends State<DesktopVideoCollectionsPage> {
  late final VideoCollectionsOverviewController _controller;
  late final VideoCollectionsApi _api;

  @override
  void initState() {
    super.initState();
    _api = context.read<VideoCollectionsApi>();
    _controller = VideoCollectionsOverviewController(collectionsApi: _api)
      ..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      unawaited(_controller.refresh());
    }
  }

  Future<void> _edit(VideoCollectionDto collection) async {
    final updated =
        await showVideoCollectionDialog(context, existing: collection);
    if (updated != null) {
      unawaited(_controller.refresh());
    }
  }

  Future<void> _delete(VideoCollectionDto collection) async {
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
      await _api.deleteCollection(collection.id);
      await _controller.refresh();
      if (mounted) {
        showToast('已删除');
      }
    } catch (_) {
      if (mounted) {
        showToast('删除失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.appSpacing.lg),
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
                  onPressed: _create,
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.lg),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.isLoading) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }
                final error = _controller.errorMessage;
                if (error != null) {
                  return AppEmptyState(message: error);
                }
                if (_controller.collections.isEmpty) {
                  return const AppEmptyState(
                    message: '暂无合集，点击「新建合集」创建',
                  );
                }
                return Wrap(
                  spacing: context.appSpacing.md,
                  runSpacing: context.appSpacing.md,
                  children: [
                    for (final collection in _controller.collections)
                      SizedBox(
                        width: 280,
                        child: CollectionCard.video(
                          collection: collection,
                          onTap: () => context.go(
                            '$desktopVideoCollectionsPath/${collection.id}',
                          ),
                          onEdit: () => _edit(collection),
                          onDelete: () => _delete(collection),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

