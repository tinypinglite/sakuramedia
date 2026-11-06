import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_option_tile.dart';
import 'package:sakuramedia/widgets/base/forms/app_search_field.dart';

/// 「加入合集」选择器的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum AddToClipCollectionPresentation { dialog, bottomDrawer }

/// 弹出「加入合集」选择器，勾选切换切片与合集的归属（即时生效）。
///
/// 关闭方式不固定（X / 点遮罩 / 下滑），不依赖返回值传递结果；调用方关闭后统一刷新合集即可。
Future<void> showAddToClipCollectionDialog(
  BuildContext context, {
  required int clipId,
  AddToClipCollectionPresentation presentation =
      AddToClipCollectionPresentation.dialog,
}) {
  switch (presentation) {
    case AddToClipCollectionPresentation.dialog:
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => AddToClipCollectionDialog(clipId: clipId),
      );
    case AddToClipCollectionPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('add-to-clip-collection-bottom-sheet'),
        heightFactor: 0.7,
        builder: (sheetContext) => AddToClipCollectionDialog(
          clipId: clipId,
          presentation: AddToClipCollectionPresentation.bottomDrawer,
        ),
      );
  }
}

class AddToClipCollectionDialog extends ConsumerStatefulWidget {
  const AddToClipCollectionDialog({
    super.key,
    required this.clipId,
    this.presentation = AddToClipCollectionPresentation.dialog,
  });

  final int clipId;
  final AddToClipCollectionPresentation presentation;

  @override
  ConsumerState<AddToClipCollectionDialog> createState() =>
      _AddToClipCollectionDialogState();
}

class _AddToClipCollectionDialogState
    extends ConsumerState<AddToClipCollectionDialog> {
  List<ClipCollectionDto> _collections = const <ClipCollectionDto>[];
  final Set<int> _selectedIds = <int>{};
  final Set<int> _updatingIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isBottomDrawer =>
      widget.presentation == AddToClipCollectionPresentation.bottomDrawer;

  List<ClipCollectionDto> get _visibleCollections {
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
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final clipsApi = ref.read(clipsApiProvider);
    try {
      // 与合集列表页 / 批量选择器共享 overview 缓存，避免每次打开重复全量拉取。
      final collections = await ref.read(
        clipCollectionsOverviewProvider.future,
      );
      // 切片详情携带 collections（后端对称影片 playlists），用于回显已加入项。
      final detail = await clipsApi.getClipDetail(clipId: widget.clipId);
      if (!mounted) {
        return;
      }
      setState(() {
        _collections = collections;
        _selectedIds
          ..clear()
          ..addAll(detail.collections.map((item) => item.id));
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
          ).clipCollectionCollectionsLoadFailed,
          l10n: AppLocalizations.of(context),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight = _isBottomDrawer
        ? MediaQuery.sizeOf(context).height * 0.5
        : 320.0;
    final content = _buildContent(context, maxListHeight: maxListHeight);
    if (_isBottomDrawer) {
      return content;
    }
    return AppDesktopDialog(
      dialogKey: const Key('add-to-clip-collection-dialog'),
      width: context.appComponentTokens.playlistDialogWidth,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context, {required double maxListHeight}) {
    final spacing = context.appSpacing;
    final isAnyUpdating = _updatingIds.isNotEmpty;
    final l10n = AppLocalizations.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        AbsorbPointer(
          absorbing: isAnyUpdating,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.clipCollectionAddToCollection,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                  AppIconButton(
                    key: const Key('add-to-clip-collection-create-button'),
                    tooltip: l10n.clipCollectionCreate,
                    onPressed: _createCollection,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              AppSearchField(
                fieldKey: const Key('add-to-clip-collection-search-field'),
                controller: _searchController,
                hintText: l10n.clipCollectionSearchHint,
                onChanged: (value) =>
                    setState(() => _keyword = value.trim().toLowerCase()),
                clearKey: const Key('add-to-clip-collection-search-clear'),
              ),
              SizedBox(height: spacing.lg),
              _buildList(context, maxListHeight: maxListHeight),
            ],
          ),
        ),
        if (isAnyUpdating)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildList(BuildContext context, {required double maxListHeight}) {
    if (_isLoading) {
      return const SizedBox(
        key: Key('add-to-clip-collection-loading'),
        height: 160,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_errorMessage != null) {
      return SizedBox(
        height: 160,
        child: AppEmptyState(message: _errorMessage!),
      );
    }
    if (_collections.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            AppLocalizations.of(context).clipCollectionEmptyCreateHint,
          ),
        ),
      );
    }
    final visibleCollections = _visibleCollections;
    if (visibleCollections.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(AppLocalizations.of(context).clipCollectionNoMatch),
        ),
      );
    }

    final spacing = context.appSpacing;
    final isAnyUpdating = _updatingIds.isNotEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxListHeight),
      child: ListView.separated(
        key: const Key('add-to-clip-collection-list'),
        shrinkWrap: true,
        itemCount: visibleCollections.length,
        separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
        itemBuilder: (context, index) {
          final collection = visibleCollections[index];
          final selected = _selectedIds.contains(collection.id);
          return AppPickerOptionTile.text(
            selected: selected,
            enabled: !isAnyUpdating,
            onTap: () => _toggle(collection),
            title: collection.name,
            trailingText: collection.clipCount > 0
                ? '${collection.clipCount}'
                : null,
            optionKey: Key('add-to-clip-collection-option-${collection.id}'),
            checkboxKey: Key(
              'add-to-clip-collection-checkbox-${collection.id}',
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(ClipCollectionDto collection) async {
    final api = ref.read(clipCollectionsApiProvider);
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
        await api.removeClipFromCollection(
          collectionId: collection.id,
          clipId: widget.clipId,
        );
      } else {
        await api.addClipToCollection(
          collectionId: collection.id,
          clipId: widget.clipId,
        );
      }
    } catch (error) {
      // 失败回滚勾选状态。
      setState(() {
        if (isSelected) {
          _selectedIds.add(collection.id);
        } else {
          _selectedIds.remove(collection.id);
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: isSelected
              ? l10n.clipCollectionRemoveFailed
              : l10n.clipCollectionAddFailed,
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

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: _isBottomDrawer
          ? ClipCollectionEditPresentation.bottomDrawer
          : ClipCollectionEditPresentation.dialog,
    );
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _collections = <ClipCollectionDto>[created, ..._collections];
    });
    await _toggle(created);
  }
}
