import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/features/tags/presentation/tag_movie_summary_content.dart';
import 'package:sakuramedia/features/tags/presentation/widgets/tag_browse_surface.dart';
import 'package:sakuramedia/features/tags/presentation/widgets/tag_selection_summary.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';

/// 标签页：标签浏览态 + 所选标签下的影片列表。
///
/// [mobile] 是两端唯一的平台差异入口；桌面和移动入口只负责固定该值。
class TagsPage extends ConsumerStatefulWidget {
  const TagsPage({super.key, required this.mobile, this.initialTagId});

  final bool mobile;

  /// 从影片详情页跳入时携带的预选标签；为空表示一级导航入口。
  final int? initialTagId;

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  late final TagSelectionScope _selectionScope = widget.initialTagId == null
      ? widget.mobile
            ? const TagSelectionScope.mobileRoot()
            : const TagSelectionScope.desktopRoot()
      : widget.mobile
      ? TagSelectionScope.mobileDetail(initialTagId: widget.initialTagId!)
      : TagSelectionScope.desktopDetail(initialTagId: widget.initialTagId!);
  late final MovieSummaryScope _movieScope = MovieSummaryScope.tags(
    instanceKey: _selectionScope.instanceKey,
    cacheKey: _selectionScope.cacheKey,
    initialTagIds: _selectionScope.initialSelectedTagIds,
    initialTagMatch: _selectionScope.initialMatchMode,
  );
  RiverpodPageHandle? _pageCacheHandle;
  late bool _browseMode;
  List<int>? _snapshotTagIds;
  TagMatchMode? _snapshotMatchMode;

  @override
  void initState() {
    super.initState();
    _browseMode =
        widget.initialTagId == null &&
        !ref.read(tagSelectionProvider(_selectionScope)).hasSelection;
    final cacheKey = _selectionScope.cacheKey;
    if (cacheKey == null) {
      return;
    }
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: cacheKey,
          resolveLinks: () {
            final selectionLink = ref
                .read(tagSelectionProvider(_selectionScope).notifier)
                .cacheLink;
            final moviesLink = ref
                .read(movieSummaryProvider(_movieScope).notifier)
                .cacheLink;
            return [?selectionLink, ?moviesLink];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(tagSelectionProvider(_selectionScope));
    if (_browseMode || !selection.hasSelection) {
      return TagBrowseSurface(
        key: const Key('tags-page'),
        scope: _selectionScope,
        mobile: widget.mobile,
        onConfirm: _confirmBrowse,
        onCancel: _snapshotTagIds == null ? null : _cancelBrowse,
      );
    }

    return TagMovieSummaryContent(
      key: const Key('tags-page'),
      selection: selection,
      headerLeading: TagSelectionSummary(
        scope: _selectionScope,
        mobile: widget.mobile,
        onEdit: _enterBrowseFromResults,
        onRemoveTag: _removeTag,
        onClear: _clearTags,
      ),
      scope: _movieScope,
      surfaceColor: widget.mobile
          ? context.appColors.surfaceCard
          : context.appColors.surfaceElevated,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: widget.mobile
          ? context.appSpacing.md
          : context.appSpacing.lg,
      enableRefresh: widget.mobile,
      registerPageRefresh: !widget.mobile,
      onRefreshFailure: widget.mobile ? _showRefreshFailure : null,
      onMovieTap: _openMovieDetail,
      headerBuilder: widget.mobile ? _buildMobileHeader : null,
      usePinnedMobileHeader: widget.mobile,
      useMobileSelectionLayout: widget.mobile,
      bodyBuilder: _buildBody,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScrollController scrollController,
    Widget sliver,
    Future<void> Function()? onRefresh,
  ) {
    final storageKey = PageStorageKey<String>(
      '${_selectionScope.instanceKey}:movies',
    );
    if (widget.mobile) {
      return AppAdaptiveRefreshScrollView(
        key: storageKey,
        onRefresh: onRefresh!,
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[sliver],
      );
    }
    return CustomScrollView(
      key: storageKey,
      controller: scrollController,
      slivers: [sliver],
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) {
    final l10n = AppLocalizations.of(context);
    final filterLabel = args.filterState.triggerLabel(l10n);
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: const Key('mobile-tags-page-total'),
        countLabel: l10n.tagMovieCountLabel(args.total),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('mobile-tags-filter-button'),
          summary: filterLabel,
          isActive: args.filterState.hasActiveFilters,
          onPressed: () => _openFilterDrawer(context, args),
        ),
        MovieSortMenuButton(
          triggerKey: const Key('mobile-tags-sort-trigger'),
          drawerKey: const Key('mobile-tags-sort-drawer'),
          filterState: args.filterState,
          onChanged: args.onApply,
          useDrawer: true,
          iconOnly: true,
        ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) async {
    await showMobileMovieFilterDrawer(
      context,
      current: args.filterState,
      onChanged: args.onApply,
    );
  }

  void _openMovieDetail(BuildContext context, String movieNumber) {
    if (widget.mobile) {
      MobileRoutes.movieDetail(movieNumber: movieNumber).push(context);
      return;
    }
    DesktopRoutes.movieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopTagsPath,
    ).push(context);
  }

  void _showRefreshFailure(BuildContext context) {
    showToast(
      AppLocalizations.of(context).tagRefreshFailed,
      tone: AppToastTone.error,
    );
  }

  void _confirmBrowse() {
    if (!ref.read(tagSelectionProvider(_selectionScope)).hasSelection) {
      return;
    }
    _setBrowseMode(false);
  }

  void _enterBrowseFromResults() {
    final selection = ref.read(tagSelectionProvider(_selectionScope));
    setState(() {
      _snapshotTagIds = List<int>.of(selection.selectedTagIds);
      _snapshotMatchMode = selection.matchMode;
      _browseMode = true;
    });
  }

  void _cancelBrowse() {
    final tagIds = _snapshotTagIds;
    final matchMode = _snapshotMatchMode;
    if (tagIds != null && matchMode != null) {
      ref
          .read(tagSelectionProvider(_selectionScope).notifier)
          .replaceSelection(tagIds, matchMode: matchMode);
    }
    _setBrowseMode(false);
  }

  void _removeTag(int tagId) {
    final notifier = ref.read(tagSelectionProvider(_selectionScope).notifier);
    notifier.remove(tagId);
    if (!ref.read(tagSelectionProvider(_selectionScope)).hasSelection) {
      _setBrowseMode(true);
    }
  }

  void _clearTags() {
    ref.read(tagSelectionProvider(_selectionScope).notifier).clear();
    _setBrowseMode(true);
  }

  void _setBrowseMode(bool enabled) {
    setState(() {
      _browseMode = enabled;
      _snapshotTagIds = null;
      _snapshotMatchMode = null;
    });
  }
}
