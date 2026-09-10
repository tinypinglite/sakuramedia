import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<void> showAddToMomentCollectionDialog(
  BuildContext context, {
  required int pointId,
  required bool useBottomDrawer,
}) {
  final dialog = AddToMomentCollectionDialog(
    pointId: pointId,
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
    required this.pointId,
    required this.useBottomDrawer,
  });

  final int pointId;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final results = await Future.wait<Object>([
        api.getCollections(),
        api.getPointCollections(pointId: widget.pointId),
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
                  '加入时刻合集',
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
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final broadcaster = ref.read(
        momentCollectionMutationEventsProvider.notifier,
      );
      if (selected) {
        await api.removePoint(
          collectionId: collection.id,
          pointId: widget.pointId,
        );
      } else {
        await api.addPoint(
          collectionId: collection.id,
          pointId: widget.pointId,
        );
      }
      broadcaster.reportChanged(collection.id);
    } catch (error) {
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
