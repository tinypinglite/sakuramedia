import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';

/// 视频合集创建/编辑的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum VideoCollectionEditPresentation { dialog, bottomDrawer }

/// 打开视频合集创建/编辑对话框。[existing] 为空表示创建。返回最新 [VideoCollectionDto]。
Future<VideoCollectionDto?> showVideoCollectionDialog(
  BuildContext context, {
  VideoCollectionDto? existing,
  VideoCollectionEditPresentation presentation =
      VideoCollectionEditPresentation.dialog,
}) {
  final l10n = AppLocalizations.of(context);
  final isEditing = existing != null;
  return showCollectionEditor<VideoCollectionDto>(
    context,
    config: CollectionEditorConfig<VideoCollectionDto>(
      presentation: switch (presentation) {
        VideoCollectionEditPresentation.dialog =>
          CollectionEditorPresentation.dialog,
        VideoCollectionEditPresentation.bottomDrawer =>
          CollectionEditorPresentation.bottomFormSheet,
      },
      keyPrefix: 'video-collection',
      copy: CollectionEditorCopy(
        title: isEditing ? l10n.videoEditCollection : l10n.videoNewCollection,
        nameHint: l10n.videoCollectionNameHint,
        descriptionHint: l10n.videoCollectionDescriptionHint,
        nameRequiredMessage: l10n.videoCollectionNameRequired,
        submitLabel: isEditing ? l10n.commonSave : l10n.videoCreateCollection,
      ),
      initialName: existing?.name ?? '',
      initialDescription: existing?.description ?? '',
      headerStyle: CollectionEditorHeaderStyle.strong,
      dialogWidth: 420,
      drawerKey: const Key('video-collection-edit-bottom-sheet'),
      drawerMaxHeightFactor: 0.62,
      errorFallback: (l10n) =>
          isEditing ? l10n.videoSaveFailed : l10n.videoCreateFailed,
      onSubmit: (ref, name, description) {
        final api = ref.read(videoCollectionsApiProvider);
        if (existing == null) {
          return api.createCollection(name: name, description: description);
        }
        return api.updateCollection(
          collectionId: existing.id,
          payload: VideoCollectionUpdatePayload(
            name: name.trim(),
            description: description.trim(),
          ),
        );
      },
    ),
  );
}
