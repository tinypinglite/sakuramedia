import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 「加入合集」的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum AddToVideoCollectionPresentation { dialog, bottomDrawer }

/// 弹出「加入合集」选择器，勾选切换视频与合集的归属（即时生效）。
///
/// [collectedRefs] 为该视频当前所属合集（列表 / 详情响应里的 `collections`），
/// 用于打开时回显已加入项；点行勾选 = 加入，取消勾选 = 移出，与切片 / 时刻的
/// 「加入合集」弹窗行为一致。
///
/// 关闭方式不固定（X / 点遮罩 / 下滑），不依赖返回值传递结果；调用方关闭后
/// 统一广播合集成员变化刷新列表即可。
Future<void> showAddToVideoCollectionDialog(
  BuildContext context, {
  required int videoItemId,
  List<VideoCollectionRef> collectedRefs = const <VideoCollectionRef>[],
  AddToVideoCollectionPresentation presentation =
      AddToVideoCollectionPresentation.dialog,
}) {
  switch (presentation) {
    case AddToVideoCollectionPresentation.dialog:
      return showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AddToVideoCollectionDialog(
          videoItemId: videoItemId,
          collectedRefs: collectedRefs,
        ),
      );
    case AddToVideoCollectionPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('add-to-video-collection-bottom-sheet'),
        maxHeightFactor: 0.7,
        builder: (sheetContext) => AddToVideoCollectionDialog(
          videoItemId: videoItemId,
          collectedRefs: collectedRefs,
          presentation: AddToVideoCollectionPresentation.bottomDrawer,
        ),
      );
  }
}

class AddToVideoCollectionDialog extends ConsumerStatefulWidget {
  const AddToVideoCollectionDialog({
    super.key,
    required this.videoItemId,
    this.collectedRefs = const <VideoCollectionRef>[],
    this.presentation = AddToVideoCollectionPresentation.dialog,
  });

  final int videoItemId;

  /// 视频当前所属合集，用于回显已加入项。
  final List<VideoCollectionRef> collectedRefs;

  final AddToVideoCollectionPresentation presentation;

  @override
  ConsumerState<AddToVideoCollectionDialog> createState() =>
      _AddToVideoCollectionDialogState();
}

class _AddToVideoCollectionDialogState
    extends ConsumerState<AddToVideoCollectionDialog> {
  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  final Set<int> _selectedIds = <int>{};
  final Set<int> _updatingIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isBottomDrawer =>
      widget.presentation == AddToVideoCollectionPresentation.bottomDrawer;

  List<VideoCollectionDto> get _visibleCollections {
    if (_keyword.isEmpty) {
      return _collections;
    }
    return _collections
        .where((collection) => collection.name.toLowerCase().contains(_keyword))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.collectedRefs.map((ref) => ref.id));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      // 与列表页 / 目标选择器共享 overview 缓存，避免每次打开重复全量拉取。
      final collections = await ref.read(
        videoCollectionsOverviewProvider.future,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _collections = collections;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: AppLocalizations.of(
            context,
          ).videoCollectionsLoadFailedShort,
          l10n: AppLocalizations.of(context),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (_isBottomDrawer) {
      return content;
    }
    return AppDesktopDialog(width: 420, showCloseButton: false, child: content);
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final isAnyUpdating = _updatingIds.isNotEmpty;
    return AbsorbPointer(
      absorbing: isAnyUpdating,
      child: Column(
        mainAxisSize: _isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPickerHeader(
            title: l10n.videoAddToCollection,
            searchController: _searchController,
            searchFieldKey: const Key('add-to-video-collection-search-field'),
            searchHintText: l10n.videoSearchCollections,
            onSearchChanged: (value) =>
                setState(() => _keyword = value.trim().toLowerCase()),
            clearSearchKey: const Key('add-to-video-collection-search-clear'),
            onClose: () => Navigator.of(context).pop(),
            closeKey: const Key('add-to-video-collection-close-button'),
            doneKey: const Key('add-to-video-collection-done-button'),
          ),
          SizedBox(height: spacing.lg),
          AppPickerListFrame(
            isDrawer: _isBottomDrawer,
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const AppPickerIosState(
        key: Key('add-to-video-collection-loading'),
        loading: true,
      );
    }
    if (_errorMessage != null) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(
          message: _errorMessage!,
          onRetry: () => _load(showLoading: true),
          retryKey: const Key('add-to-video-collection-retry'),
        ),
        action: _buildCreateRow(AppLocalizations.of(context), enabled: true),
      );
    }
    if (_collections.isEmpty) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(
          message: AppLocalizations.of(context).videoCollectionsEmptyDialog,
        ),
        action: _buildCreateRow(AppLocalizations.of(context), enabled: true),
      );
    }
    final visibleCollections = _visibleCollections;
    if (visibleCollections.isEmpty) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(
          message: AppLocalizations.of(context).videoCollectionsNoMatch,
        ),
        action: _buildCreateRow(AppLocalizations.of(context), enabled: true),
      );
    }
    final isAnyUpdating = _updatingIds.isNotEmpty;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const Key('add-to-video-collection-list'),
      child: AppPickerIosSection(
        header: Text(
          l10n.commonSelectedCount(_selectedIds.length),
          key: const Key('add-to-video-collection-selected-count'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        children: [
          _buildCreateRow(l10n, enabled: !isAnyUpdating),
          for (final collection in visibleCollections)
            AppPickerIosRow(
              selected: _selectedIds.contains(collection.id),
              showCheckmark: true,
              enabled: !isAnyUpdating,
              busy: _updatingIds.contains(collection.id),
              busyKey: Key('add-to-video-collection-updating-${collection.id}'),
              onTap: () => _toggle(collection),
              title: collection.name,
              trailingText: collection.itemCount > 0
                  ? '${collection.itemCount}'
                  : null,
              optionKey: Key('add-to-video-collection-option-${collection.id}'),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateRow(AppLocalizations l10n, {required bool enabled}) {
    return AppPickerIosActionRow(
      label: l10n.videoCreateCollectionAndAdd,
      enabled: enabled,
      onTap: _createAndAdd,
      optionKey: const Key('add-to-video-collection-create-button'),
    );
  }

  Future<void> _toggle(VideoCollectionDto collection) async {
    final api = ref.read(videoCollectionsApiProvider);
    final l10n = AppLocalizations.of(context);
    final isSelected = _selectedIds.contains(collection.id);
    setState(() {
      _updatingIds.add(collection.id);
      if (isSelected) {
        _selectedIds.remove(collection.id);
      } else {
        _selectedIds.add(collection.id);
      }
    });
    try {
      if (isSelected) {
        await api.removeVideoFromCollection(
          collectionId: collection.id,
          videoItemId: widget.videoItemId,
        );
      } else {
        await api.addVideoToCollection(
          collectionId: collection.id,
          videoItemId: widget.videoItemId,
        );
      }
    } catch (error) {
      // 失败回滚勾选状态。
      if (mounted) {
        setState(() {
          if (isSelected) {
            _selectedIds.add(collection.id);
          } else {
            _selectedIds.remove(collection.id);
          }
        });
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: isSelected
              ? l10n.videoRemoveFromCollectionFailed
              : l10n.videoAddToCollectionFailedShort,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(collection.id));
      }
    }
  }

  Future<void> _createAndAdd() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: _isBottomDrawer
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _collections = <VideoCollectionDto>[created, ..._collections];
      _errorMessage = null;
    });
    await _toggle(created);
  }
}
