import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

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
    showDesktopCloseButton: false,
    builder: (_) => _PickVideoCollectionSingleDialog(
      selectedCollectionId: selectedCollectionId,
    ),
  );
}

class _PickVideoCollectionSingleDialog extends ConsumerStatefulWidget {
  const _PickVideoCollectionSingleDialog({required this.selectedCollectionId});

  final int? selectedCollectionId;

  @override
  ConsumerState<_PickVideoCollectionSingleDialog> createState() =>
      _PickVideoCollectionSingleDialogState();
}

class _PickVideoCollectionSingleDialogState
    extends ConsumerState<_PickVideoCollectionSingleDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  List<VideoCollectionDto> _visibleCollections(
    List<VideoCollectionDto> collections,
  ) {
    if (_keyword.isEmpty) {
      return collections;
    }
    return collections
        .where((collection) => collection.name.toLowerCase().contains(_keyword))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final collectionsAsync = ref.watch(videoCollectionsOverviewProvider);
    return Column(
      mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerHeader(
          title: l10n.videoSelectCollection,
          searchController: _searchController,
          searchFieldKey: const Key(
            'pick-video-collection-single-search-field',
          ),
          searchHintText: l10n.videoSearchCollections,
          onSearchChanged: (value) =>
              setState(() => _keyword = value.trim().toLowerCase()),
          clearSearchKey: const Key(
            'pick-video-collection-single-search-clear',
          ),
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('pick-video-collection-single-close-button'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(
          isDrawer: isDrawer,
          child: _buildBody(context, collectionsAsync),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> collectionsAsync,
  ) {
    if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
      return const AppPickerIosState(loading: true);
    }
    if (collectionsAsync.hasError && !collectionsAsync.hasValue) {
      return AppPickerIosState(
        message: apiErrorMessage(
          collectionsAsync.error!,
          fallback: AppLocalizations.of(
            context,
          ).videoCollectionsLoadFailedShort,
          l10n: AppLocalizations.of(context),
        ),
      );
    }
    final collections = collectionsAsync.value ?? <VideoCollectionDto>[];
    final visible = _visibleCollections(collections);
    final noneSelected = widget.selectedCollectionId == null;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const Key('pick-video-collection-single-list'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPickerIosSection(
            children: [
              AppPickerIosRow(
                selected: noneSelected,
                showCheckmark: true,
                onTap: () => Navigator.of(
                  context,
                ).pop(const VideoCollectionSelection(null)),
                title: l10n.videoNoCollection,
                optionKey: const Key('pick-video-collection-single-none'),
              ),
              for (final collection in visible)
                AppPickerIosRow(
                  selected: widget.selectedCollectionId == collection.id,
                  showCheckmark: true,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(VideoCollectionSelection(collection.id)),
                  title: collection.name,
                  trailingText: collection.itemCount > 0
                      ? '${collection.itemCount}'
                      : null,
                  optionKey: Key(
                    'pick-video-collection-single-${collection.id}',
                  ),
                ),
            ],
          ),
          if (visible.isEmpty)
            AppPickerIosState(
              message: collections.isEmpty
                  ? l10n.videoCollectionsEmptyShort
                  : l10n.videoCollectionsNoMatch,
            ),
        ],
      ),
    );
  }
}
