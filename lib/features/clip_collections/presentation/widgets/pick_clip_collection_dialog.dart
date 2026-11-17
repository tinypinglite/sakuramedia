import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_target_picker.dart';

/// 选择一个目标切片合集（批量加入合集用）。返回选中的合集；取消返回 `null`。
///
/// 与单条即时加入的 [showAddToClipCollectionDialog] 不同：本弹窗只负责「选中并返回」，
/// 实际加入动作由调用方批量执行。三处「加入合集」选择器共用
/// [showCollectionTargetPicker]，本函数只适配本域的数据源、行文案和新建入口。
Future<ClipCollectionDto?> showPickClipCollectionDialog(
  BuildContext context, {
  AppAdaptiveModalVariant presentation = AppAdaptiveModalVariant.dialog,
  int? excludedCollectionId,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionTargetPicker<ClipCollectionDto>(
    context: context,
    variant: presentation,
    drawerKey: const Key('pick-clip-collection-bottom-sheet'),
    optionKeyPrefix: 'pick-clip-collection-',
    watchCollections: (ref) => ref.watch(clipCollectionsOverviewProvider),
    idOf: (collection) => collection.id,
    nameOf: (collection) => collection.name,
    countTextOf: (collection) =>
        l10n.clipCollectionClipCount(collection.clipCount),
    excludedCollectionId: excludedCollectionId,
    onCreate: (context, isDrawer) => showCreateClipCollectionDialog(
      context,
      presentation: isDrawer
          ? CollectionEditorPresentation.drawer
          : CollectionEditorPresentation.dialog,
    ),
  );
}
