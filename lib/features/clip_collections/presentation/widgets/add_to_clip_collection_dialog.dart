import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_membership_dialog.dart';

/// 「加入合集」选择器的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum AddToClipCollectionPresentation { dialog, bottomDrawer }

/// 弹出「加入合集」选择器，勾选切换切片与合集的归属（即时生效）。
Future<void> showAddToClipCollectionDialog(
  BuildContext context, {
  required int clipId,
  AddToClipCollectionPresentation presentation =
      AddToClipCollectionPresentation.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionMembershipDialog<ClipCollectionDto>(
    context: context,
    variant: switch (presentation) {
      AddToClipCollectionPresentation.dialog => AppAdaptiveModalVariant.dialog,
      AddToClipCollectionPresentation.bottomDrawer =>
        AppAdaptiveModalVariant.drawer,
    },
    config: CollectionMembershipConfig<ClipCollectionDto>(
      keyPrefix: 'add-to-clip-collection',
      title: l10n.clipCollectionAddToCollection,
      searchHint: l10n.clipCollectionSearchHint,
      createLabel: l10n.clipCollectionCreate,
      emptyMessage: l10n.clipCollectionEmptyCreateHint,
      noMatchMessage: l10n.clipCollectionNoMatch,
      loadErrorFallback: l10n.clipCollectionCollectionsLoadFailed,
      addErrorFallback: l10n.clipCollectionAddFailed,
      removeErrorFallback: l10n.clipCollectionRemoveFailed,
      loadCollections: (ref) =>
          ref.read(clipCollectionsOverviewProvider.future),
      loadSelectedIds: (ref) async {
        final detail = await ref
            .read(clipsApiProvider)
            .getClipDetail(clipId: clipId);
        return detail.collections.map((collection) => collection.id).toSet();
      },
      add: (ref, collectionId) => ref
          .read(clipCollectionsApiProvider)
          .addClipToCollection(collectionId: collectionId, clipId: clipId),
      remove: (ref, collectionId) => ref
          .read(clipCollectionsApiProvider)
          .removeClipFromCollection(collectionId: collectionId, clipId: clipId),
      createCollection: (context, ref) => showCreateClipCollectionDialog(
        context,
        presentation: AppAdaptiveModalShellScope.maybeIsDrawer(context)
            ? ClipCollectionEditPresentation.bottomDrawer
            : ClipCollectionEditPresentation.dialog,
      ),
      idOf: (collection) => collection.id,
      nameOf: (collection) => collection.name,
      countOf: (collection) => collection.clipCount,
      dialogKey: const Key('add-to-clip-collection-dialog'),
      drawerKey: const Key('add-to-clip-collection-bottom-sheet'),
    ),
  );
}
