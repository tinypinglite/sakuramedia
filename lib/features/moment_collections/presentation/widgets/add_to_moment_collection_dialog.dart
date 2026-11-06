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
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
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
    showDesktopCloseButton: false,
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
  int? _updatingId;
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

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
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
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AbsorbPointer(
      absorbing: _updatingId != null,
      child: Column(
        mainAxisSize: _isDrawer ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPickerHeader(
            title: l10n.momentAddToCollection,
            searchController: _searchController,
            searchFieldKey: const Key('add-to-moment-collection-search-field'),
            searchHintText: l10n.momentCollectionSearchHint,
            onSearchChanged: (value) =>
                setState(() => _keyword = value.trim().toLowerCase()),
            clearSearchKey: const Key('add-to-moment-collection-search-clear'),
            onClose: () => Navigator.of(context).pop(),
            closeKey: const Key('add-to-moment-collection-close-button'),
            doneKey: const Key('add-to-moment-collection-done-button'),
          ),
          SizedBox(height: spacing.lg),
          AppPickerListFrame(isDrawer: _isDrawer, child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const AppPickerIosState(
        key: Key('add-to-moment-collection-loading'),
        loading: true,
      );
    }
    if (_error != null) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(
          message: _error!,
          onRetry: () => _load(showLoading: true),
          retryKey: const Key('add-to-moment-collection-retry'),
        ),
        action: _buildCreateRow(l10n, enabled: true),
      );
    }
    if (_collections.isEmpty) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(message: l10n.momentCollectionEmptyAddDialog),
        action: _buildCreateRow(l10n, enabled: true),
      );
    }
    final visibleCollections = _visibleCollections;
    if (visibleCollections.isEmpty) {
      return AppPickerIosStateWithAction(
        state: AppPickerIosState(message: l10n.momentCollectionNoMatch),
        action: _buildCreateRow(l10n, enabled: true),
      );
    }
    return SingleChildScrollView(
      key: const Key('add-to-moment-collection-list'),
      child: AppPickerIosSection(
        header: Text(
          l10n.commonSelectedCount(_selectedIds.length),
          key: const Key('add-to-moment-collection-selected-count'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        children: [
          _buildCreateRow(l10n, enabled: _updatingId == null),
          for (final collection in visibleCollections)
            AppPickerIosRow(
              selected: _selectedIds.contains(collection.id),
              showCheckmark: true,
              enabled: _updatingId == null,
              busy: _updatingId == collection.id,
              busyKey: Key(
                'add-to-moment-collection-updating-${collection.id}',
              ),
              onTap: () =>
                  _toggle(collection, _selectedIds.contains(collection.id)),
              title: collection.name,
              trailingText: collection.pointCount > 0
                  ? '${collection.pointCount}'
                  : null,
              optionKey: Key('add-to-moment-collection-${collection.id}'),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateRow(AppLocalizations l10n, {required bool enabled}) {
    return AppPickerIosActionRow(
      label: l10n.momentCollectionCreateTitle,
      enabled: enabled,
      onTap: _createCollection,
      optionKey: const Key('add-to-moment-collection-create-button'),
    );
  }

  Future<void> _toggle(MomentCollectionDto collection, bool selected) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _updatingId = collection.id;
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
      if (mounted) setState(() => _updatingId = null);
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
