import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

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
        builder:
            (sheetContext) => AddToClipCollectionDialog(
              clipId: clipId,
              presentation: AddToClipCollectionPresentation.bottomDrawer,
            ),
      );
  }
}

class AddToClipCollectionDialog extends StatefulWidget {
  const AddToClipCollectionDialog({
    super.key,
    required this.clipId,
    this.presentation = AddToClipCollectionPresentation.dialog,
  });

  final int clipId;
  final AddToClipCollectionPresentation presentation;

  @override
  State<AddToClipCollectionDialog> createState() =>
      _AddToClipCollectionDialogState();
}

class _AddToClipCollectionDialogState extends State<AddToClipCollectionDialog> {
  static const double _checkboxScale = 0.85;

  List<ClipCollectionDto> _collections = const <ClipCollectionDto>[];
  final Set<int> _selectedIds = <int>{};
  final Set<int> _updatingIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isBottomDrawer =>
      widget.presentation == AddToClipCollectionPresentation.bottomDrawer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collectionsApi = context.read<ClipCollectionsApi>();
    final clipsApi = context.read<ClipsApi>();
    try {
      final collections = await collectionsApi.getCollections();
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
        _errorMessage = apiErrorMessage(error, fallback: '合集加载失败');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxListHeight =
        _isBottomDrawer ? MediaQuery.sizeOf(context).height * 0.5 : 320.0;
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
                      '加入合集',
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
                    tooltip: '新建合集',
                    onPressed: _createCollection,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
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
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return SizedBox(height: 160, child: AppEmptyState(message: _errorMessage!));
    }
    if (_collections.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('还没有合集，点右上角「+」新建')),
      );
    }

    final spacing = context.appSpacing;
    final isAnyUpdating = _updatingIds.isNotEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxListHeight),
      child: ListView.separated(
        key: const Key('add-to-clip-collection-list'),
        shrinkWrap: true,
        itemCount: _collections.length,
        separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
        itemBuilder: (context, index) {
          final collection = _collections[index];
          final selected = _selectedIds.contains(collection.id);
          return InkWell(
            key: Key('add-to-clip-collection-option-${collection.id}'),
            borderRadius: context.appRadius.xsBorder,
            onTap: isAnyUpdating ? null : () => _toggle(collection),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              decoration: BoxDecoration(
                color: context.appColors.surfaceMuted,
                borderRadius: context.appRadius.xsBorder,
                border: Border.all(
                  color:
                      selected
                          ? Theme.of(context).colorScheme.primary
                          : context.appColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Transform.scale(
                    scale: _checkboxScale,
                    child: Checkbox(
                      key: Key('add-to-clip-collection-checkbox-${collection.id}'),
                      value: selected,
                      onChanged:
                          isAnyUpdating ? null : (_) => _toggle(collection),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                  if (collection.clipCount > 0)
                    Text(
                      '${collection.clipCount}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(ClipCollectionDto collection) async {
    final api = context.read<ClipCollectionsApi>();
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
      showToast(apiErrorMessage(error, fallback: isSelected ? '移出合集失败' : '加入合集失败'));
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(collection.id));
      }
    }
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation:
          _isBottomDrawer
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
