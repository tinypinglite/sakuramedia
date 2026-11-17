import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 新建切片合集，成功返回新建的合集。
Future<ClipCollectionDto?> showCreateClipCollectionDialog(
  BuildContext context, {
  CollectionEditorPresentation presentation =
      CollectionEditorPresentation.dialog,
}) {
  return _showClipCollectionEditDialog(context, presentation: presentation);
}

/// 编辑已有合集（名称 / 描述），成功返回更新后的合集。
Future<ClipCollectionDto?> showEditClipCollectionDialog(
  BuildContext context, {
  required ClipCollectionDto collection,
  CollectionEditorPresentation presentation =
      CollectionEditorPresentation.dialog,
}) {
  return _showClipCollectionEditDialog(
    context,
    collection: collection,
    presentation: presentation,
  );
}

Future<ClipCollectionDto?> _showClipCollectionEditDialog(
  BuildContext context, {
  ClipCollectionDto? collection,
  required CollectionEditorPresentation presentation,
}) {
  final l10n = AppLocalizations.of(context);
  final isEditing = collection != null;
  return showCollectionEditor<ClipCollectionDto>(
    context,
    config: CollectionEditorConfig<ClipCollectionDto>(
      presentation: presentation,
      keyPrefix: 'clip-collection',
      copy: CollectionEditorCopy(
        title: isEditing ? l10n.clipCollectionEdit : l10n.clipCollectionCreate,
        nameHint: l10n.clipCollectionNameHint,
        descriptionHint: l10n.clipCollectionDescriptionHint,
        nameRequiredMessage: l10n.clipCollectionNameRequired,
        submitLabel: isEditing
            ? l10n.commonSave
            : l10n.clipCollectionCreateAction,
      ),
      initialName: collection?.name ?? '',
      initialDescription: collection?.description ?? '',
      errorFallback: (l10n) => isEditing
          ? l10n.clipCollectionSaveFailed
          : l10n.clipCollectionCreateFailed,
      drawerKey: const Key('clip-collection-edit-bottom-sheet'),
      drawerMaxHeightFactor: 0.62,
      onSubmit: (ref, name, description) {
        final api = ref.read(clipCollectionsApiProvider);
        if (collection == null) {
          return api.createCollection(name: name, description: description);
        }
        return api.updateCollection(
          collectionId: collection.id,
          payload: UpdateClipCollectionPayload(
            name: name.trim(),
            description: description.trim(),
          ),
        );
      },
    ),
  );
}
