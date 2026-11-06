import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';

/// 在合集详情里弹出「添加切片」选择器：默认只看未加入，勾选即时加入 / 移出。
///
/// 关闭方式不固定（X / 点遮罩 / 抽屉「完成」），不依赖返回值；调用方关闭后刷新
/// 合集详情即可。桌面端用居中弹窗，移动端用底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<void> showAddClipsToCollectionDialog(
  BuildContext context, {
  required int collectionId,
  required Set<int> memberClipIds,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    dialogKey: const Key('add-clips-to-collection-dialog'),
    drawerKey: const Key('add-clips-to-collection-bottom-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileHeightFactor: 0.8,
    showDesktopCloseButton: false,
    builder: (_) => AddClipsToCollectionDialog(
      collectionId: collectionId,
      memberClipIds: memberClipIds,
    ),
  );
}

class AddClipsToCollectionDialog extends ConsumerStatefulWidget {
  const AddClipsToCollectionDialog({
    super.key,
    required this.collectionId,
    required this.memberClipIds,
  });

  final int collectionId;
  final Set<int> memberClipIds;

  @override
  ConsumerState<AddClipsToCollectionDialog> createState() =>
      _AddClipsToCollectionDialogState();
}

class _AddClipsToCollectionDialogState
    extends ConsumerState<AddClipsToCollectionDialog> {
  static const int _pageSize = 24;
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<MediaClipDto> _clips = <MediaClipDto>[];
  late final Set<int> _memberIds;
  final Set<int> _updatingIds = <int>{};
  Timer? _searchTimer;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _onlyUnadded = true;
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
    _memberIds = <int>{...widget.memberClipIds};
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
        _clips
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
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: AppLocalizations.of(context).clipCollectionClipsLoadFailed,
          l10n: AppLocalizations.of(context),
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
        final loadedIds = _clips.map((clip) => clip.clipId).toSet();
        final incoming = result.items
            .skip(skip)
            .where((clip) => !loadedIds.contains(clip.clipId));
        final consumed = math.max(0, result.items.length - skip);
        _clips.addAll(incoming);
        _nextOffset += consumed;
        _total = consumed == 0 ? _nextOffset : result.total;
        _loadMoreErrorMessage = null;
      });
    } catch (error) {
      if (mounted && seq == _requestSeq) {
        setState(() {
          final message = apiErrorMessage(
            error,
            fallback: AppLocalizations.of(
              context,
            ).clipCollectionClipsLoadFailed,
            l10n: AppLocalizations.of(context),
          );
          if (_clips.isEmpty) {
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

  Future<PaginatedResponseDto<MediaClipDto>> _fetch({required int page}) {
    return ref
        .read(clipsApiProvider)
        .getMyClips(
          page: page,
          pageSize: _pageSize,
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
          title: l10n.clipCollectionAddClips,
          searchController: _searchController,
          searchFieldKey: const Key('add-clips-search-field'),
          searchHintText: l10n.clipCollectionSearchClipsHint,
          clearSearchKey: const Key('add-clips-search-clear'),
          onSearchChanged: _onSearchChanged,
          chips: <Widget>[
            AppPickerIosChip(
              key: const Key('add-clips-only-unadded-chip'),
              label: l10n.clipCollectionOnlyUnadded,
              selected: _onlyUnadded,
              onPressed: () => _setOnlyUnadded(!_onlyUnadded),
            ),
          ],
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('add-clips-close-button'),
          doneKey: const Key('add-clips-done-button'),
        ),
        SizedBox(height: spacing.lg),
        // 抽屉高度固定，列表占满剩余空间；弹窗按内容收缩。
        _isDrawer ? Expanded(child: body) : body,
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _clips.isEmpty) {
      return _buildLoadingOptions(context, key: const Key('add-clips-loading'));
    }
    if (_errorMessage != null) {
      return AppPickerIosState(
        key: const Key('add-clips-error'),
        message: _errorMessage!,
        onRetry: _loadInitial,
      );
    }
    if (_clips.isEmpty) {
      if (_hasMore) {
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
        ? l10n.clipCollectionAddedAvailableCount(_memberIds.length, _total)
        : l10n.clipCollectionAddedTotalCount(_memberIds.length, _total);
    final list = AppPagedLoadMoreScope(
      canLoadMore: () =>
          !_isLoading &&
          !_isLoadingMore &&
          _hasMore &&
          _errorMessage == null &&
          _loadMoreErrorMessage == null,
      onLoadMore: _loadMore,
      child: SingleChildScrollView(
        key: const Key('add-clips-list'),
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerIosSection(
              dividerIndent: 84,
              header: Text(
                countLabel,
                key: const Key('add-clips-count'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
              children: [
                for (final clip in _clips) _buildClipOption(context, clip),
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
        key: const Key('add-clips-empty-search'),
        title: l10n.clipCollectionNoMatchingClips,
        message: l10n.clipCollectionTryAnotherKeyword,
      );
    }
    if (_onlyUnadded) {
      return AppPickerIosState(
        key: const Key('add-clips-empty-all-added'),
        title: l10n.clipCollectionAllAdded,
        message: l10n.clipCollectionAllAddedHint,
        actionLabel: l10n.clipCollectionViewAll,
        onRetry: () => _setOnlyUnadded(false),
        retryKey: const Key('add-clips-show-all-button'),
      );
    }
    return AppPickerIosState(
      key: const Key('add-clips-empty-library'),
      title: l10n.clipCollectionNoClipsTitle,
      message: l10n.clipCollectionNoClipsHint,
    );
  }

  Widget _buildLoadingOptions(BuildContext context, {Key? key}) {
    final placeholders = clipPlaceholders();
    // loading 用占位切片渲染真实选项行，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      key: key,
      enabled: true,
      child: AppPickerIosSection(
        dividerIndent: 84,
        children: [
          for (final clip in placeholders) _buildClipOption(context, clip),
        ],
      ),
    );
  }

  Widget _buildClipOption(BuildContext context, MediaClipDto clip) {
    final selected = _memberIds.contains(clip.clipId);
    final isAnyUpdating = _updatingIds.isNotEmpty;
    final coverUrl = clip.coverImage?.origin;
    final title = clip.title.trim();
    final l10n = AppLocalizations.of(context);
    final metaParts = <String>[
      if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
        clip.movieNumber!
      else
        l10n.clipCollectionNoMovieNumber,
      formatMediaTimecode(clip.durationSeconds),
    ];

    return AppPickerIosRow(
      optionKey: Key('add-clips-option-${clip.clipId}'),
      leading: AppPickerIosCover(url: coverUrl),
      selected: selected,
      showCheckmark: true,
      enabled: !isAnyUpdating,
      busy: isAnyUpdating && _updatingIds.contains(clip.clipId),
      busyKey: Key('add-clips-updating-${clip.clipId}'),
      onTap: () => _toggle(clip),
      title: title.isEmpty ? l10n.clipCollectionUntitledClip : title,
      subtitle: metaParts.join(' · '),
    );
  }

  Future<void> _toggle(MediaClipDto clip) async {
    if (_updatingIds.isNotEmpty) {
      return;
    }
    final api = ref.read(clipCollectionsApiProvider);
    final isMember = _memberIds.contains(clip.clipId);
    setState(() {
      _updatingIds.add(clip.clipId);
      if (isMember) {
        _memberIds.remove(clip.clipId);
      } else {
        _memberIds.add(clip.clipId);
      }
    });
    try {
      if (isMember) {
        await api.removeClipFromCollection(
          collectionId: widget.collectionId,
          clipId: clip.clipId,
        );
        if (!mounted) {
          return;
        }
        showToast(
          AppLocalizations.of(context).clipCollectionMovedOutToast,
          tone: AppToastTone.success,
        );
      } else {
        await api.addClipToCollection(
          collectionId: widget.collectionId,
          clipId: clip.clipId,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          // 仅未加入视图里"加入即出池"：本地移出的这一条同时从服务端过滤集消失，
          // 已消费游标和总数都要回退，否则下一页会从错位处开始、漏掉边界项。
          if (_onlyUnadded) {
            _clips.removeWhere((item) => item.clipId == clip.clipId);
            _total = math.max(0, _total - 1);
            _nextOffset = math.max(0, _nextOffset - 1);
          }
        });
        showToast(
          AppLocalizations.of(context).clipCollectionAddedToast,
          tone: AppToastTone.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (isMember) {
          _memberIds.add(clip.clipId);
        } else {
          _memberIds.remove(clip.clipId);
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: isMember
              ? AppLocalizations.of(context).clipCollectionRemoveFailed
              : AppLocalizations.of(context).clipCollectionAddFailed,
          l10n: AppLocalizations.of(context),
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(clip.clipId));
      }
    }
  }
}
