import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_membership_dialog.dart';

Future<void> showAddToMomentCollectionDialog(
  BuildContext context, {
  int? pointId,
  int? mediaId,
  int? thumbnailId,
}) {
  assert(
    pointId != null || (mediaId != null && thumbnailId != null),
    'pointId or mediaId + thumbnailId is required',
  );
  final l10n = AppLocalizations.of(context);
  var resolvedPointId = pointId;
  return showCollectionMembershipDialog<MomentCollectionDto>(
    context: context,
    config: CollectionMembershipConfig<MomentCollectionDto>(
      keyPrefix: 'add-to-moment-collection',
      searchHint: l10n.momentCollectionSearchHint,
      createLabel: l10n.momentCollectionCreateTitle,
      emptyMessage: l10n.momentCollectionEmptyAddDialog,
      noMatchMessage: l10n.momentCollectionNoMatch,
      loadErrorFallback: l10n.momentErrorCollectionsLoadFailed,
      addErrorFallback: l10n.momentErrorAddToCollectionFailed,
      removeErrorFallback: l10n.momentErrorRemoveFromCollectionBriefFailed,
      loadCollections: (ref) =>
          ref.read(momentCollectionsOverviewProvider.future),
      loadSelectedIds: (ref) async {
        final currentPointId = resolvedPointId;
        if (currentPointId == null) {
          return <int>{};
        }
        final collections = await ref
            .read(momentCollectionsApiProvider)
            .getPointCollections(pointId: currentPointId);
        return collections.map((collection) => collection.id).toSet();
      },
      add: (ref, collectionId) async {
        final api = ref.read(momentCollectionsApiProvider);
        final broadcaster = ref.read(
          momentCollectionMutationEventsProvider.notifier,
        );
        MediaPointDto? createdPoint;
        try {
          if (resolvedPointId == null) {
            createdPoint = await ref
                .read(mediaApiProvider)
                .createMediaPoint(mediaId: mediaId!, thumbnailId: thumbnailId!);
            resolvedPointId = createdPoint.pointId;
          }
          await api.addPoint(
            collectionId: collectionId,
            pointId: resolvedPointId!,
          );
          broadcaster.reportChanged(collectionId);
        } catch (_) {
          if (createdPoint != null) {
            try {
              await ref
                  .read(mediaApiProvider)
                  .deleteMediaPoint(pointId: createdPoint.pointId);
            } catch (_) {
              // 加入合集失败时尽量回收刚创建的标记；原始错误仍反馈给用户。
            }
            resolvedPointId = null;
          }
          rethrow;
        }
      },
      remove: (ref, collectionId) async {
        final currentPointId = resolvedPointId;
        if (currentPointId == null) {
          return;
        }
        await ref
            .read(momentCollectionsApiProvider)
            .removePoint(collectionId: collectionId, pointId: currentPointId);
        ref
            .read(momentCollectionMutationEventsProvider.notifier)
            .reportChanged(collectionId);
      },
      createCollection: (context, ref) => showMomentCollectionEditor(context),
      idOf: (collection) => collection.id,
      nameOf: (collection) => collection.name,
      countOf: (collection) => collection.pointCount,
      optionKeyBuilder: (collectionId) =>
          Key('add-to-moment-collection-$collectionId'),
      dialogKey: const Key('add-to-moment-collection-dialog'),
      drawerKey: const Key('add-to-moment-collection-drawer'),
    ),
  );
}
