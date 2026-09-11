import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<void> showAddToMomentCollectionDialog(
  BuildContext context, {
  int? pointId,
  int? mediaId,
  int? thumbnailId,
  required bool useBottomDrawer,
}) {
  final dialog = AddToMomentCollectionDialog(
    pointId: pointId,
    mediaId: mediaId,
    thumbnailId: thumbnailId,
    useBottomDrawer: useBottomDrawer,
  );
  return useBottomDrawer
      ? showAppBottomDrawer<void>(
          context: context,
          drawerKey: const Key('add-to-moment-collection-drawer'),
          maxHeightFactor: 0.7,
          builder: (_) => dialog,
        )
      : showDialog<void>(context: context, builder: (_) => dialog);
}

class AddToMomentCollectionDialog extends ConsumerStatefulWidget {
  const AddToMomentCollectionDialog({
    super.key,
    this.pointId,
    this.mediaId,
    this.thumbnailId,
    required this.useBottomDrawer,
  }) : assert(
         pointId != null || (mediaId != null && thumbnailId != null),
         'pointId or mediaId + thumbnailId is required',
       );

  /// 已存在的时刻传 pointId；以图搜图尚未添加标记的结果传 mediaId + thumbnailId，
  /// 在用户第一次选中合集时才创建时刻，取消弹窗不会留下孤立标记。
  final int? pointId;
  final int? mediaId;
  final int? thumbnailId;
  final bool useBottomDrawer;

  @override
  ConsumerState<AddToMomentCollectionDialog> createState() =>
      _AddToMomentCollectionDialogState();
}

class _AddToMomentCollectionDialogState
    extends ConsumerState<AddToMomentCollectionDialog> {
  List<MomentCollectionDto> _collections = const [];
  final Set<int> _selectedIds = <int>{};
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isCreating = false;
  String? _error;
  int? _pointId;

  @override
  void initState() {
    super.initState();
    _pointId = widget.pointId;
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final results = await Future.wait<Object>([
        api.getCollections(),
        _pointId == null
            ? Future<List<MomentCollectionSummaryDto>>.value(
                const <MomentCollectionSummaryDto>[],
              )
            : api.getPointCollections(pointId: _pointId!),
      ]);
      if (!mounted) return;
      setState(() {
        _collections = results[0] as List<MomentCollectionDto>;
        _selectedIds
          ..clear()
          ..addAll(
            (results[1] as List<MomentCollectionSummaryDto>).map(
              (item) => item.id,
            ),
          );
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(error, fallback: '合集加载失败');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isCreating
        ? MomentCollectionEditor(
            onCancel: _cancelCreate,
            onSaved: _finishCreate,
          )
        : _buildContent(context);
    return widget.useBottomDrawer
        ? content
        : AppDesktopDialog(
            width: context.appComponentTokens.playlistDialogWidth,
            child: content,
          );
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    return AbsorbPointer(
      absorbing: _isUpdating,
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
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppIconButton(
                tooltip: '新建合集',
                icon: const Icon(Icons.add_rounded),
                onPressed: _isLoading || _isUpdating ? null : _createCollection,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _buildList(context),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_error != null) {
      return SizedBox(height: 180, child: AppEmptyState(message: _error!));
    }
    if (_collections.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('还没有合集，点右上角「+」新建')),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.useBottomDrawer ? 320 : 280,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _collections.length,
        separatorBuilder: (_, _) => SizedBox(height: context.appSpacing.xs),
        itemBuilder: (context, index) {
          final collection = _collections[index];
          final selected = _selectedIds.contains(collection.id);
          return CheckboxListTile(
            key: Key('add-to-moment-collection-${collection.id}'),
            value: selected,
            title: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${collection.pointCount} 个时刻'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (_) => _toggle(collection, selected),
          );
        },
      ),
    );
  }

  Future<void> _toggle(MomentCollectionDto collection, bool selected) async {
    setState(() {
      _isUpdating = true;
      if (selected) {
        _selectedIds.remove(collection.id);
      } else {
        _selectedIds.add(collection.id);
      }
    });
    MediaPointDto? createdPoint;
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final broadcaster = ref.read(
        momentCollectionMutationEventsProvider.notifier,
      );
      if (!selected && _pointId == null) {
        createdPoint = await ref
            .read(mediaApiProvider)
            .createMediaPoint(
              mediaId: widget.mediaId!,
              thumbnailId: widget.thumbnailId!,
            );
        if (!mounted) return;
        _pointId = createdPoint.pointId;
      }
      final pointId = _pointId;
      if (pointId == null) return;
      if (selected) {
        await api.removePoint(collectionId: collection.id, pointId: pointId);
      } else {
        await api.addPoint(collectionId: collection.id, pointId: pointId);
      }
      broadcaster.reportChanged(collection.id);
    } catch (error) {
      if (createdPoint != null) {
        try {
          await ref
              .read(mediaApiProvider)
              .deleteMediaPoint(
                mediaId: widget.mediaId!,
                pointId: createdPoint.pointId,
              );
        } catch (_) {
          // 加入合集失败时尽量回收刚创建的标记；原始错误仍反馈给用户。
        }
        _pointId = null;
      }
      if (mounted) {
        setState(() {
          if (selected) {
            _selectedIds.add(collection.id);
          } else {
            _selectedIds.remove(collection.id);
          }
        });
      }
      showToast(
        apiErrorMessage(error, fallback: selected ? '移出合集失败' : '加入合集失败'),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _createCollection() => setState(() => _isCreating = true);

  void _cancelCreate() => setState(() => _isCreating = false);

  void _finishCreate(MomentCollectionDto collection) {
    setState(() {
      _collections = <MomentCollectionDto>[collection, ..._collections];
      _error = null;
      _isCreating = false;
    });
    unawaited(_toggle(collection, false));
  }
}
