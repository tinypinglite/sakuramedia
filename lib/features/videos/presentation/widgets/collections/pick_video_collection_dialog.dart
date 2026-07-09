import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 目标合集选择器的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum PickVideoCollectionPresentation { dialog, bottomDrawer }

/// 选择一个目标视频合集（批量加入合集用）。返回选中的合集；取消返回 `null`。
///
/// 与单条即时加入的 [showAddToVideoCollectionDialog] 不同：本弹窗只负责「选中并返回」，
/// 实际加入动作由调用方批量执行。
Future<VideoCollectionDto?> showPickVideoCollectionDialog(
  BuildContext context, {
  PickVideoCollectionPresentation presentation =
      PickVideoCollectionPresentation.dialog,
  int? excludedCollectionId,
}) {
  switch (presentation) {
    case PickVideoCollectionPresentation.dialog:
      return showDialog<VideoCollectionDto>(
        context: context,
        builder: (dialogContext) => _PickVideoCollectionDialog(
          excludedCollectionId: excludedCollectionId,
        ),
      );
    case PickVideoCollectionPresentation.bottomDrawer:
      return showAppBottomDrawer<VideoCollectionDto>(
        context: context,
        drawerKey: const Key('pick-video-collection-bottom-sheet'),
        maxHeightFactor: 0.7,
        builder: (sheetContext) => _PickVideoCollectionDialog(
          presentation: PickVideoCollectionPresentation.bottomDrawer,
          excludedCollectionId: excludedCollectionId,
        ),
      );
  }
}

class _PickVideoCollectionDialog extends StatefulWidget {
  const _PickVideoCollectionDialog({
    this.presentation = PickVideoCollectionPresentation.dialog,
    this.excludedCollectionId,
  });

  final PickVideoCollectionPresentation presentation;

  /// 不在列表中显示的合集 id（用于「加入到另一个合集」时排除当前合集自身）。
  final int? excludedCollectionId;

  @override
  State<_PickVideoCollectionDialog> createState() =>
      _PickVideoCollectionDialogState();
}

class _PickVideoCollectionDialogState
    extends State<_PickVideoCollectionDialog> {
  late final VideoCollectionsApi _api;
  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  bool _isLoading = true;
  String? _error;

  bool get _isBottomDrawer =>
      widget.presentation == PickVideoCollectionPresentation.bottomDrawer;

  @override
  void initState() {
    super.initState();
    _api = context.read<VideoCollectionsApi>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final collections = await _api.getCollections();
      if (!mounted) {
        return;
      }
      final excluded = widget.excludedCollectionId;
      setState(() {
        _collections = excluded == null
            ? collections
            : collections
                .where((c) => c.id != excluded)
                .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = apiErrorMessage(error, fallback: '合集加载失败');
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndPick() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: _isBottomDrawer
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (_isBottomDrawer) {
      return content;
    }
    return AppDesktopDialog(width: 420, child: content);
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    // 抽屉形态：列表占据抽屉剩余空间并内部滚动，表头/按钮常驻，整体由抽屉 maxHeightFactor
    // 约束，避免矮屏上「表头 + 固定高列表 + 按钮」超过抽屉封顶导致溢出。桌面弹窗仍用固定上限。
    final listSection = _isBottomDrawer
        ? Flexible(child: _buildBody(context))
        : ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _buildBody(context),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '加入合集',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        listSection,
        SizedBox(height: spacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '新建合集并加入',
                onPressed: _createAndPick,
              ),
            ),
            SizedBox(width: spacing.md),
            AppButton(
              label: '关闭',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return AppEmptyState(message: _error!);
    }
    if (_collections.isEmpty) {
      return const AppEmptyState(message: '暂无合集，点击下方新建');
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _collections.length,
      separatorBuilder: (context, _) => SizedBox(height: context.appSpacing.xs),
      itemBuilder: (context, index) {
        final collection = _collections[index];
        return ListTile(
          key: Key('pick-collection-${collection.id}'),
          title: Text(collection.name),
          subtitle: Text('${collection.itemCount} 个视频'),
          trailing: const Icon(Icons.add),
          onTap: () => Navigator.of(context).pop(collection),
        );
      },
    );
  }
}
