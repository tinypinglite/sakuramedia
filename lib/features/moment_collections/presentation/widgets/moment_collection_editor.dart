import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 新建 / 编辑合集：桌面走居中弹窗，移动走底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<MomentCollectionDto?> showMomentCollectionEditor(
  BuildContext context, {
  MomentCollectionDto? collection,
}) {
  final l10n = AppLocalizations.of(context);
  final isEditing = collection != null;
  return showCollectionEditor<MomentCollectionDto>(
    context,
    config: CollectionEditorConfig<MomentCollectionDto>(
      presentation: CollectionEditorPresentation.adaptive,
      keyPrefix: 'moment-collection',
      copy: CollectionEditorCopy(
        title: isEditing
            ? l10n.momentCollectionEditTitle
            : l10n.momentCollectionCreateTitle,
        nameHint: l10n.momentCollectionNameHint,
        descriptionHint: l10n.momentCollectionDescriptionHint,
        nameRequiredMessage: l10n.momentCollectionNameRequired,
        submitLabel: isEditing ? l10n.commonSave : l10n.momentCreateAction,
      ),
      initialName: collection?.name ?? '',
      initialDescription: collection?.description ?? '',
      drawerKey: const Key('moment-collection-editor-drawer'),
      drawerMaxHeightFactor: 0.62,
      errorFallback: (l10n) =>
          isEditing ? l10n.momentErrorSaveFailed : l10n.momentErrorCreateFailed,
      onSubmit: (ref, name, description) {
        final api = ref.read(momentCollectionsApiProvider);
        if (collection == null) {
          return api.createCollection(name: name, description: description);
        }
        return api.updateCollection(
          collectionId: collection.id,
          payload: UpdateMomentCollectionPayload(
            name: name.trim(),
            description: description.trim(),
          ),
        );
      },
    ),
  );
}
