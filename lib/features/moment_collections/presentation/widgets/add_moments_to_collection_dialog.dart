import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 时刻选择器的内容类型：后端 `kind` 支持 jav / video / all。
enum _MomentKindOption {
  all(apiValue: 'all'),
  jav(apiValue: 'jav'),
  video(apiValue: 'video');

  const _MomentKindOption({required this.apiValue});

  final String apiValue;

  /// `JAV` 是内容类型代号，中英文一致，不进语言包。
  String label(AppLocalizations l10n) => switch (this) {
    _MomentKindOption.all => l10n.momentKindAll,
    _MomentKindOption.jav => 'JAV',
    _MomentKindOption.video => l10n.momentKindVideo,
  };
}

/// 在合集详情里弹出「添加时刻」选择器：默认只看未加入，勾选即时加入 / 移出。
///
/// 关闭方式不固定（X / 点遮罩 / 抽屉「完成」），不依赖返回值；调用方关闭后刷新
/// 合集详情即可。桌面端用居中弹窗，移动端用底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<void> showAddMomentsToCollectionDialog(
  BuildContext context, {
  required int collectionId,
  required Set<int> memberPointIds,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    dialogKey: const Key('add-moments-to-collection-dialog'),
    drawerKey: const Key('add-moments-to-collection-bottom-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileHeightFactor: 0.8,
    showDesktopCloseButton: false,
    builder: (_) => AddMomentsToCollectionDialog(
      collectionId: collectionId,
      memberPointIds: memberPointIds,
    ),
  );
}

class AddMomentsToCollectionDialog extends ConsumerStatefulWidget {
  const AddMomentsToCollectionDialog({
    super.key,
    required this.collectionId,
    required this.memberPointIds,
  });

  final int collectionId;
  final Set<int> memberPointIds;

  @override
  ConsumerState<AddMomentsToCollectionDialog> createState() =>
      _AddMomentsToCollectionDialogState();
}

class _AddMomentsToCollectionDialogState
    extends ConsumerState<AddMomentsToCollectionDialog> {
  static const int _pageSize = 24;
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<MediaPointListItemDto> _points = <MediaPointListItemDto>[];
  late final Set<int> _memberIds;
  final Set<int> _updatingIds = <int>{};
  Timer? _searchTimer;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _onlyUnadded = true;
  _MomentKindOption _kind = _MomentKindOption.all;
  String _keyword = '';
  int _nextOffset = 0;
  int _total = 0;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  int _requestSeq = 0;

  bool get _hasMore => _nextOffset < _total;

  bool get _isDrawer => AppAdaptiveModalShellScope.maybeIsDrawer(context);

  @override
  void initState() {
    super.initState();
    _memberIds = <int>{...widget.memberPointIds};
    _loadInitial();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreErrorMessage = null;
    });
    try {
      final result = await _fetch(page: 1);
      if (!mounted || seq != _requestSeq) {
        return;
      }
      setState(() {
        _points
          ..clear()
          ..addAll(result.items);
        _nextOffset = result.items.length;
        _total = result.total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.momentErrorPointsLoadFailed,
          l10n: l10n,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMore ||
        _loadMoreErrorMessage != null) {
      return;
    }
    final seq = _requestSeq;
    setState(() => _isLoadingMore = true);
    try {
      // 本地可能已把"刚加入"的行移出列表，按已消费偏移取下一页并跳过页内已消费段，
      // 避免整页错位漏项；服务端继续用 exclude 过滤保证不重复返回已加入项。
      final page = (_nextOffset ~/ _pageSize) + 1;
      final skip = _nextOffset % _pageSize;
      final result = await _fetch(page: page);
      if (!mounted || seq != _requestSeq) {
        return;
      }
      setState(() {
        final loadedIds = _points.map((point) => point.pointId).toSet();
        final incoming = result.items
            .skip(skip)
            .where((point) => !loadedIds.contains(point.pointId));
        final consumed = math.max(0, result.items.length - skip);
        _points.addAll(incoming);
        _nextOffset += consumed;
        _total = consumed == 0 ? _nextOffset : result.total;
        _loadMoreErrorMessage = null;
      });
    } catch (error) {
      if (mounted && seq == _requestSeq) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          final message = apiErrorMessage(
            error,
            fallback: l10n.momentErrorPointsLoadFailed,
            l10n: l10n,
          );
          if (_points.isEmpty) {
            _errorMessage = message;
          } else {
            _loadMoreErrorMessage = message;
          }
        });
      }
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreErrorMessage = null);
    unawaited(_loadMore());
  }

  Future<PaginatedResponseDto<MediaPointListItemDto>> _fetch({
    required int page,
  }) {
    return ref
        .read(mediaApiProvider)
        .getGlobalMediaPoints(
          page: page,
          pageSize: _pageSize,
          kind: _kind.apiValue,
          keyword: _keyword.isEmpty ? null : _keyword,
          excludeCollectionId: _onlyUnadded ? widget.collectionId : null,
        );
  }

  void _onSearchChanged(String raw) {
    final next = raw.trim();
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted || next == _keyword) {
        return;
      }
      setState(() => _keyword = next);
      _loadInitial();
    });
  }

  void _selectKind(_MomentKindOption kind) {
    if (kind == _kind) {
      return;
    }
    setState(() => _kind = kind);
    _loadInitial();
  }

  void _setOnlyUnadded(bool value) {
    if (value == _onlyUnadded) {
      return;
    }
    setState(() => _onlyUnadded = value);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final body = _buildBody(context);
    return Column(
      mainAxisSize: _isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerHeader(
          title: l10n.momentAddMomentsAction,
          searchController: _searchController,
          searchFieldKey: const Key('add-moments-search-field'),
          searchHintText: l10n.momentPickerSearchHint,
          clearSearchKey: const Key('add-moments-search-clear'),
          onSearchChanged: _onSearchChanged,
          chips: _buildFilterChips(context),
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('add-moments-close-button'),
          doneKey: const Key('add-moments-done-button'),
        ),
        SizedBox(height: spacing.lg),
        // 抽屉高度固定，列表占满剩余空间；弹窗按内容收缩。
        _isDrawer ? Expanded(child: body) : body,
      ],
    );
  }

  List<Widget> _buildFilterChips(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <Widget>[
      AppPickerIosChip(
        key: const Key('add-moments-only-unadded-chip'),
        label: l10n.momentPickerOnlyUnadded,
        selected: _onlyUnadded,
        onPressed: () => _setOnlyUnadded(!_onlyUnadded),
      ),
      Container(
        width: 1,
        height: context.appComponentTokens.buttonHeightXs,
        color: context.appColors.divider,
      ),
      for (final kind in _MomentKindOption.values)
        AppPickerIosChip(
          key: Key('add-moments-kind-${kind.apiValue}'),
          label: kind.label(l10n),
          selected: _kind == kind,
          onPressed: () => _selectKind(kind),
        ),
    ];
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _points.isEmpty) {
      return _buildLoadingOptions(
        context,
        key: const Key('add-moments-loading'),
      );
    }
    if (_errorMessage != null) {
      return AppPickerIosState(
        key: const Key('add-moments-error'),
        message: _errorMessage!,
        onRetry: _loadInitial,
      );
    }
    if (_points.isEmpty) {
      if (_hasMore) {
        // 已加载项被「加入后移除」清空但服务端还有候选，继续取下一页。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadMore();
          }
        });
        return _buildLoadingOptions(context);
      }
      return _buildEmptyState(context);
    }

    final l10n = AppLocalizations.of(context);
    final countLabel = _onlyUnadded
        ? l10n.momentPickerCountAvailable(_memberIds.length, _total)
        : l10n.momentPickerCountTotal(_memberIds.length, _total);
    final list = AppPagedLoadMoreScope(
      canLoadMore: () =>
          !_isLoading &&
          !_isLoadingMore &&
          _hasMore &&
          _errorMessage == null &&
          _loadMoreErrorMessage == null,
      onLoadMore: _loadMore,
      child: SingleChildScrollView(
        key: const Key('add-moments-list'),
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerIosSection(
              dividerIndent: 84,
              header: Text(
                countLabel,
                key: const Key('add-moments-count'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
              children: [
                for (final point in _points) _buildPointOption(context, point),
              ],
            ),
            if (_hasMore || _loadMoreErrorMessage != null)
              AppPagedLoadMoreFooter(
                isLoading: _loadMoreErrorMessage == null,
                errorMessage: _loadMoreErrorMessage,
                onRetry: _retryLoadMore,
              ),
          ],
        ),
      ),
    );
    if (_isDrawer) {
      return list;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: list,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_keyword.isNotEmpty) {
      return AppPickerIosState(
        key: const Key('add-moments-empty-search'),
        title: l10n.momentEmptyNoMatchTitle,
        message: l10n.momentEmptyNoMatchMessage,
      );
    }
    if (_kind != _MomentKindOption.all) {
      return AppPickerIosState(
        key: const Key('add-moments-empty-kind'),
        title: l10n.momentEmptyKindTitle,
        message: l10n.momentEmptyKindMessage,
      );
    }
    if (_onlyUnadded) {
      return AppPickerIosState(
        key: const Key('add-moments-empty-all-added'),
        title: l10n.momentEmptyAllAddedTitle,
        message: l10n.momentEmptyAllAddedMessage,
        actionLabel: l10n.momentViewAll,
        onRetry: () => _setOnlyUnadded(false),
        retryKey: const Key('add-moments-show-all-button'),
      );
    }
    return AppPickerIosState(
      key: const Key('add-moments-empty-library'),
      title: l10n.momentEmptyNoMomentsTitle,
      message: l10n.momentEmptyNoMomentsMessage,
    );
  }

  Widget _buildLoadingOptions(BuildContext context, {Key? key}) {
    final placeholders = mediaPointListItemPlaceholders();
    // loading 用占位时刻渲染真实选项行，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      key: key,
      enabled: true,
      child: AppPickerIosSection(
        dividerIndent: 84,
        children: [
          for (final point in placeholders) _buildPointOption(context, point),
        ],
      ),
    );
  }

  Widget _buildPointOption(BuildContext context, MediaPointListItemDto point) {
    final selected = _memberIds.contains(point.pointId);
    final isAnyUpdating = _updatingIds.isNotEmpty;
    final coverUrl = point.image?.origin;
    final l10n = AppLocalizations.of(context);
    final videoItemId = point.videoItemId;
    final title = point.movieNumber?.isNotEmpty == true
        ? point.movieNumber!
        : (videoItemId != null && videoItemId > 0
              ? l10n.momentVideoLabel(videoItemId)
              : l10n.momentLabel(point.pointId));

    return AppPickerIosRow(
      optionKey: Key('add-moments-option-${point.pointId}'),
      leading: AppPickerIosCover(url: coverUrl),
      selected: selected,
      showCheckmark: true,
      enabled: !isAnyUpdating,
      busy: isAnyUpdating && _updatingIds.contains(point.pointId),
      busyKey: Key('add-moments-updating-${point.pointId}'),
      onTap: () => _toggle(point),
      title: title,
      subtitle: formatMediaTimecode(point.offsetSeconds),
    );
  }

  Future<void> _toggle(MediaPointListItemDto point) async {
    if (_updatingIds.isNotEmpty) {
      return;
    }
    final api = ref.read(momentCollectionsApiProvider);
    final l10n = AppLocalizations.of(context);
    final isMember = _memberIds.contains(point.pointId);
    setState(() {
      _updatingIds.add(point.pointId);
      if (isMember) {
        _memberIds.remove(point.pointId);
      } else {
        _memberIds.add(point.pointId);
      }
    });
    try {
      if (isMember) {
        await api.removePoint(
          collectionId: widget.collectionId,
          pointId: point.pointId,
        );
        if (!mounted) {
          return;
        }
        showToast(l10n.momentMovedOutToast, tone: AppToastTone.success);
      } else {
        await api.addPoint(
          collectionId: widget.collectionId,
          pointId: point.pointId,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          // 仅未加入视图里"加入即出池"：本地移出的这一条同时从服务端过滤集消失，
          // 已消费游标和总数都要回退，否则下一页会从错位处开始、漏掉边界项。
          if (_onlyUnadded) {
            _points.removeWhere((item) => item.pointId == point.pointId);
            _total = math.max(0, _total - 1);
            _nextOffset = math.max(0, _nextOffset - 1);
          }
        });
        showToast(l10n.momentAddedToast, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (isMember) {
          _memberIds.add(point.pointId);
        } else {
          _memberIds.remove(point.pointId);
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: isMember
              ? l10n.momentErrorRemoveFromCollectionBriefFailed
              : l10n.momentErrorAddToCollectionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(point.pointId));
      }
    }
  }
}
