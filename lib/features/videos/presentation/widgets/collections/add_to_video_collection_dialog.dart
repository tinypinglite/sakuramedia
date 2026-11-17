import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_membership_dialog.dart';

/// 弹出「加入合集」选择器，勾选切换视频与合集的归属（即时生效）。
Future<void> showAddToVideoCollectionDialog(
  BuildContext context, {
  required int videoItemId,
  List<VideoCollectionRef> collectedRefs = const <VideoCollectionRef>[],
  AppAdaptiveModalVariant presentation = AppAdaptiveModalVariant.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionMembershipDialog<VideoCollectionDto>(
    context: context,
    variant: presentation,
    config: CollectionMembershipConfig<VideoCollectionDto>(
      keyPrefix: 'add-to-video-collection',
      searchHint: l10n.videoSearchCollections,
      createLabel: l10n.videoCreateCollectionAndAdd,
      emptyMessage: l10n.videoCollectionsEmptyDialog,
      noMatchMessage: l10n.videoCollectionsNoMatch,
      loadErrorFallback: l10n.videoCollectionsLoadFailedShort,
      addErrorFallback: l10n.videoAddToCollectionFailedShort,
      removeErrorFallback: l10n.videoRemoveFromCollectionFailed,
      loadCollections: (ref) =>
          ref.read(videoCollectionsOverviewProvider.future),
      loadSelectedIds: (ref) async {
        return collectedRefs.map((collection) => collection.id).toSet();
      },
      add: (ref, collectionId) => ref
          .read(videoCollectionsApiProvider)
          .addVideoToCollection(
            collectionId: collectionId,
            videoItemId: videoItemId,
          ),
      remove: (ref, collectionId) => ref
          .read(videoCollectionsApiProvider)
          .removeVideoFromCollection(
            collectionId: collectionId,
            videoItemId: videoItemId,
          ),
      createCollection: (context, ref) => showVideoCollectionDialog(
        context,
        presentation: AppAdaptiveModalShellScope.maybeIsDrawer(context)
            ? CollectionEditorPresentation.bottomFormSheet
            : CollectionEditorPresentation.dialog,
      ),
      idOf: (collection) => collection.id,
      nameOf: (collection) => collection.name,
      countOf: (collection) => collection.itemCount,
      dialogKey: const Key('add-to-video-collection-dialog'),
      drawerKey: const Key('add-to-video-collection-bottom-sheet'),
    ),
  );
}
