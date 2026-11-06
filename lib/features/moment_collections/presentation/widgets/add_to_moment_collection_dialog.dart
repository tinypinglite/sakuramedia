import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_option_tile.dart';
import 'package:sakuramedia/widgets/base/forms/app_search_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<void> showAddToMomentCollectionDialog(
  BuildContext context, {
  int? pointId,
  int? mediaId,
  int? thumbnailId,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    drawerKey: const Key('add-to-moment-collection-drawer'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileMaxHeightFactor: 0.7,
    builder: (_) => AddToMomentCollectionDialog(
      pointId: pointId,
      mediaId: mediaId,
      thumbnailId: thumbnailId,
    ),
  );
}

class AddToMomentCollectionDialog extends ConsumerStatefulWidget {
  const AddToMomentCollectionDialog({
    super.key,
    this.pointId,
    this.mediaId,
    this.thumbnailId,
  }) : assert(
         pointId != null || (mediaId != null && thumbnailId != null),
         'pointId or mediaId + thumbnailId is required',
       );

  /// 已存在的时刻传 pointId；以图搜图尚未添加标记的结果传 mediaId + thumbnailId，
  /// 在用户第一次选中合集时才创建时刻，取消弹窗不会留下孤立标记。
  final int? pointId;
  final int? mediaId;
  final int? thumbnailId;

  @override
  ConsumerState<AddToMomentCollectionDialog> createState() =>
      _AddToMomentCollectionDialogState();
}

class _AddToMomentCollectionDialogState
    extends ConsumerState<AddToMomentCollectionDialog> {
  List<MomentCollectionDto> _collections = const [];
  final Set<int> _selectedIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;
  int? _pointId;

  List<MomentCollectionDto> get _visibleCollections {
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
    _pointId = widget.pointId;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final results = await Future.wait<Object>([
        // 与合集列表页 / 批量选择器共享 overview 缓存，避免每次打开重复全量拉取。
        ref.read(momentCollectionsOverviewProvider.future),
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
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = apiErrorMessage(
            error,
            fallback: l10n.momentErrorCollectionsLoadFailed,
            l10n: l10n,
          );
          _isLoading = false;
        });
      }
    }
  }

  bool get _isDrawer => AppAdaptiveModalShellScope.maybeIsDrawer(context);

  @override
  Widget build(BuildContext context) {
    final maxListHeight = _isDrawer
        ? MediaQuery.sizeOf(context).height * 0.5
        : 320.0;
    return _buildContent(context, maxListHeight: maxListHeight);
  }

  Widget _buildContent(BuildContext context, {required double maxListHeight}) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        AbsorbPointer(
          absorbing: _isUpdating,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.momentAddToCollection,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ),
                  AppIconButton(
                    key: const Key('add-to-moment-collection-create-button'),
                    tooltip: l10n.momentCollectionCreateTitle,
                    onPressed: _isLoading || _isUpdating
                        ? null
                        : _createCollection,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              AppSearchField(
                fieldKey: const Key('add-to-moment-collection-search-field'),
                controller: _searchController,
                hintText: l10n.momentCollectionSearchHint,
                onChanged: (value) =>
                    setState(() => _keyword = value.trim().toLowerCase()),
                clearKey: const Key('add-to-moment-collection-search-clear'),
              ),
              SizedBox(height: spacing.lg),
              _buildList(context, maxListHeight: maxListHeight),
            ],
          ),
        ),
        if (_isUpdating)
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
        key: Key('add-to-moment-collection-loading'),
        height: 160,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_error != null) {
      return SizedBox(height: 160, child: AppEmptyState(message: _error!));
    }
    if (_collections.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            AppLocalizations.of(context).momentCollectionEmptyAddDialog,
          ),
        ),
      );
    }
    final visibleCollections = _visibleCollections;
    if (visibleCollections.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(AppLocalizations.of(context).momentCollectionNoMatch),
        ),
      );
    }
    final spacing = context.appSpacing;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxListHeight),
      child: ListView.separated(
        key: const Key('add-to-moment-collection-list'),
        shrinkWrap: true,
        itemCount: visibleCollections.length,
        separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
        itemBuilder: (context, index) {
          final collection = visibleCollections[index];
          final selected = _selectedIds.contains(collection.id);
          return AppPickerOptionTile.text(
            selected: selected,
            enabled: !_isUpdating,
            onTap: () => _toggle(collection, selected),
            title: collection.name,
            trailingText: collection.pointCount > 0
                ? '${collection.pointCount}'
                : null,
            optionKey: Key('add-to-moment-collection-${collection.id}'),
          );
        },
      ),
    );
  }

  Future<void> _toggle(MomentCollectionDto collection, bool selected) async {
    final l10n = AppLocalizations.of(context);
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
              .deleteMediaPoint(pointId: createdPoint.pointId);
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
        apiErrorMessage(
          error,
          fallback: selected
              ? l10n.momentErrorRemoveFromCollectionBriefFailed
              : l10n.momentErrorAddToCollectionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _createCollection() async {
    final created = await showMomentCollectionEditor(context);
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _collections = <MomentCollectionDto>[created, ..._collections];
      _error = null;
    });
    unawaited(_toggle(created, false));
  }
}
