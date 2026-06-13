import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/create_video_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

/// 把视频加入某个视频合集。返回 `true` 表示成功加入。
Future<bool?> showAddToVideoCollectionDialog(
  BuildContext context, {
  required int videoItemId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        AddToVideoCollectionDialog(videoItemId: videoItemId),
  );
}

class AddToVideoCollectionDialog extends StatefulWidget {
  const AddToVideoCollectionDialog({super.key, required this.videoItemId});

  final int videoItemId;

  @override
  State<AddToVideoCollectionDialog> createState() =>
      _AddToVideoCollectionDialogState();
}

class _AddToVideoCollectionDialogState
    extends State<AddToVideoCollectionDialog> {
  late final VideoCollectionsApi _api;
  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  bool _isLoading = true;
  String? _error;
  int? _busyCollectionId;

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

  Future<void> _addTo(VideoCollectionDto collection) async {
    setState(() => _busyCollectionId = collection.id);
    try {
      await _api.addCollectionItem(
        collectionId: collection.id,
        videoItemId: widget.videoItemId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '加入合集失败'));
      if (mounted) {
        setState(() => _busyCollectionId = null);
      }
    }
  }

  Future<void> _createAndAdd() async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      await _addTo(created);
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
                  onPressed: _createAndAdd,
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
        final isBusy = _busyCollectionId == collection.id;
        return ListTile(
          key: Key('add-to-collection-${collection.id}'),
          title: Text(collection.name),
          subtitle: Text('${collection.itemCount} 个视频'),
          trailing: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          onTap: isBusy ? null : () => _addTo(collection),
        );
      },
    );
  }
}
