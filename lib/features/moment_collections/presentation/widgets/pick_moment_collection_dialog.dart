import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_target_picker.dart';

/// 批量加入合集时选择一个目标合集。实际成员写入由调用方执行。
///
/// 三处「加入合集」选择器共用 [showCollectionTargetPicker]，本函数只适配本域的
/// 数据源、行文案和新建入口。
Future<MomentCollectionDto?> showPickMomentCollectionDialog(
  BuildContext context, {
  int? excludedCollectionId,
}) {
  final l10n = AppLocalizations.of(context);
  return showCollectionTargetPicker<MomentCollectionDto>(
    context: context,
    drawerKey: const Key('pick-moment-collection-bottom-sheet'),
    optionKeyPrefix: 'pick-moment-collection-',
    watchCollections: (ref) => ref.watch(momentCollectionsOverviewProvider),
    idOf: (collection) => collection.id,
    nameOf: (collection) => collection.name,
    countTextOf: (collection) => l10n.momentCountLabel(collection.pointCount),
    excludedCollectionId: excludedCollectionId,
    onCreate: (context, _) => showMomentCollectionEditor(context),
  );
}
