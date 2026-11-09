import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_list_content.dart';

/// 视频合集列表共享内容：搜索、新建/编辑/删除、mutation 刷新和合集网格。
class VideoCollectionsContent extends ConsumerStatefulWidget {
  const VideoCollectionsContent({super.key, required this.mobile});

  final bool mobile;

  @override
  ConsumerState<VideoCollectionsContent> createState() =>
      _VideoCollectionsContentState();
}

class _VideoCollectionsContentState
    extends ConsumerState<VideoCollectionsContent> {
  bool _refreshScheduled = false;

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
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    });
  }

  Future<void> _refresh() {
    return ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

  Future<void> _open(
    BuildContext context,
    VideoCollectionDto collection,
  ) async {
    if (widget.mobile) {
      await MobileRoutes.videoCollectionDetail(
        collectionId: collection.id,
      ).push<void>(context);
      return;
    }
    DesktopRoutes.videoCollectionDetail(
      collectionId: collection.id,
    ).push(context);
  }

  Future<void> _create(BuildContext context) async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: widget.mobile
          ? CollectionEditorPresentation.bottomFormSheet
          : CollectionEditorPresentation.dialog,
    );
    if (!mounted || !context.mounted || created == null) {
      return;
    }
    await _refresh();
    if (!mounted || !context.mounted) {
      return;
    }
    if (widget.mobile) {
      showToast(
        AppLocalizations.of(context).videoCollectionCreated,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    VideoCollectionDto collection,
  ) async {
    final updated = await showVideoCollectionDialog(
      context,
      existing: collection,
      presentation: widget.mobile
          ? CollectionEditorPresentation.bottomFormSheet
          : CollectionEditorPresentation.dialog,
    );
    if (!mounted || !context.mounted || updated == null) {
      return;
    }
    await _refresh();
    if (!mounted || !context.mounted) {
      return;
    }
    if (widget.mobile) {
      showToast(
        AppLocalizations.of(context).commonSaved,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    VideoCollectionDto collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteCollectionTitle,
      message: widget.mobile
          ? l10n.videoDeleteCollectionConfirmMessageNamed(
              name.isEmpty ? l10n.videoGenericCollection : '“$name”',
            )
          : l10n.videoDeleteCollectionConfirmMessage(collection.name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: widget.mobile
          ? const Key('mobile-video-collection-delete-drawer')
          : null,
      confirmKey: widget.mobile
          ? const Key('mobile-video-collection-delete-confirm-button')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .deleteCollection(collection.id);
      await _refresh();
      if (mounted) {
        showToast(l10n.videoCollectionDeleted, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        widget.mobile
            ? apiErrorMessage(
                error,
                fallback: l10n.videoDeleteFailed,
                l10n: l10n,
              )
            : l10n.videoDeleteFailedLater,
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<VideoMutationChange>>(videoMutationEventsProvider, (
      previous,
      next,
    ) {
      final change = next.value;
      if (change != null) {
        _onMutation(change);
      }
    });

    final l10n = AppLocalizations.of(context);
    return CollectionListContent<VideoCollectionDto>(
      mobile: widget.mobile,
      keyPrefix: widget.mobile
          ? 'mobile-video-collections'
          : 'video-collections',
      title: l10n.videoCollectionsTitle,
      searchHint: l10n.videoSearchCollections,
      createLabel: l10n.videoNewCollection,
      emptyDesktopMessage: l10n.videoCollectionsEmpty,
      emptyMobileMessage: l10n.videoCollectionsEmptyMobile,
      noMatchMessage: l10n.videoCollectionsNoMatch,
      loadErrorMessage: l10n.videoCollectionsLoadFailed,
      collections: ref.watch(videoCollectionsOverviewProvider),
      onRefresh: _refresh,
      placeholders: (mobile) =>
          videoCollectionPlaceholders(count: mobile ? 6 : 4),
      nameOf: (collection) => collection.name,
      cardBuilder:
          (
            context,
            collection, {
            required onTap,
            required onEdit,
            required onDelete,
          }) => CollectionCard.video(
            key: widget.mobile
                ? Key('mobile-video-collection-card-${collection.id}')
                : null,
            collection: collection,
            coverBackdrop: widget.mobile,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      onOpen: _open,
      onCreate: _create,
      onEdit: _edit,
      onDelete: _delete,
    );
  }
}
