import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/create_video_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

/// 选择一个目标视频合集（批量加入合集用）。返回选中的合集；取消返回 `null`。
///
/// 与单条即时加入的 [showAddToVideoCollectionDialog] 不同：本弹窗只负责「选中并返回」，
/// 实际加入动作由调用方批量执行。
Future<VideoCollectionDto?> showPickVideoCollectionDialog(
  BuildContext context,
) {
  return showDialog<VideoCollectionDto>(
    context: context,
    builder: (dialogContext) => const _PickVideoCollectionDialog(),
  );
}

class _PickVideoCollectionDialog extends StatefulWidget {
  const _PickVideoCollectionDialog();

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
      setState(() {
        _collections = collections;
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
    final created = await showVideoCollectionDialog(context);
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      width: 420,
      child: Column(
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _buildBody(context),
          ),
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
      ),
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
