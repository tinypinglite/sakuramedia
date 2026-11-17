import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_picker_results.dart';

/// 单选合集的返回值：`collectionId == null` 表示「不加入合集」。
/// 整个弹层取消时返回 `null`（与「不加入合集」区分）。
class VideoCollectionSelection {
  const VideoCollectionSelection(this.collectionId);

  final int? collectionId;
}

/// 单选一个视频合集（导入表单用）：带搜索与「不加入合集」选项，取消返回 `null`。
Future<VideoCollectionSelection?> showPickVideoCollectionSingleDialog(
  BuildContext context, {
  required int? selectedCollectionId,
}) {
  return showAppAdaptiveModal<VideoCollectionSelection>(
    context: context,
    drawerKey: const Key('pick-video-collection-single-drawer'),
    desktopWidth: 420,
    mobileMaxHeightFactor: 0.7,
    showDesktopCloseButton: true,
    builder: (_) => _PickVideoCollectionSingleDialog(
      selectedCollectionId: selectedCollectionId,
    ),
  );
}

class _PickVideoCollectionSingleDialog extends ConsumerWidget {
  const _PickVideoCollectionSingleDialog({required this.selectedCollectionId});

  final int? selectedCollectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final collectionsAsync = ref.watch(videoCollectionsOverviewProvider);
    return CollectionPickerResults<VideoCollectionDto>(
      collections: collectionsAsync,
      chrome: (
        keyPrefix: 'pick-video-collection-single',
        emptyMessage: l10n.videoCollectionsEmptyShort,
      ),
      nameOf: (collection) => collection.name,
      rowsBuilder: (context, visible) => [
        if (!(collectionsAsync.hasError && !collectionsAsync.hasValue))
          AppPickerIosRow(
            selected: selectedCollectionId == null,
            showCheckmark: true,
            onTap: () =>
                Navigator.of(context).pop(const VideoCollectionSelection(null)),
            title: l10n.videoNoCollection,
            optionKey: const Key('pick-video-collection-single-none'),
          ),
        for (final collection in visible)
          AppPickerIosRow(
            selected: selectedCollectionId == collection.id,
            showCheckmark: true,
            onTap: () => Navigator.of(
              context,
            ).pop(VideoCollectionSelection(collection.id)),
            title: collection.name,
            trailingText: collection.itemCount > 0
                ? '${collection.itemCount}'
                : null,
            optionKey: Key('pick-video-collection-single-${collection.id}'),
          ),
      ],
    );
  }
}
