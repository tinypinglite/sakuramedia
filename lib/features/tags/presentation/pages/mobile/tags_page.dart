import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
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
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';

/// 移动端标签页：标签浏览态 + 所选标签下的影片列表。
class MobileTagsPage extends ConsumerStatefulWidget {
  const MobileTagsPage({super.key, this.initialTagId});

  /// 从影片详情页跳入时携带的预选标签；为空表示抽屉一级入口。
  final int? initialTagId;

  @override
  ConsumerState<MobileTagsPage> createState() => _MobileTagsPageState();
}

class _MobileTagsPageState extends ConsumerState<MobileTagsPage> {
  late final TagSelectionScope _selectionScope = widget.initialTagId == null
      ? const TagSelectionScope.mobileRoot()
      : TagSelectionScope.mobileDetail(initialTagId: widget.initialTagId!);
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
            return [
              if (selectionLink != null) selectionLink,
              if (moviesLink != null) moviesLink,
            ];
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
        mobile: true,
        onConfirm: _confirmBrowse,
        onCancel: _snapshotTagIds == null ? null : _cancelBrowse,
      );
    }

    return TagMovieSummaryContent(
      key: const Key('tags-page'),
      selection: selection,
      headerLeading: TagSelectionSummary(
        scope: _selectionScope,
        mobile: true,
        onEdit: _enterBrowseFromResults,
        onRemoveTag: _removeTag,
        onClear: _clearTags,
      ),
      scope: _movieScope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('tags-page-movies'),
      totalKey: const Key('tags-page-total'),
      sectionSpacing: context.appSpacing.md,
      enableRefresh: true,
      onRefreshFailure: (_) => showToast(
        AppLocalizations.of(context).tagRefreshFailed,
        tone: AppToastTone.error,
      ),
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      headerBuilder: _buildMobileHeader,
      useMobileSelectionLayout: true,
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: PageStorageKey<String>(
              '${_selectionScope.instanceKey}:movies',
            ),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterButtonKey: const Key('mobile-tags-filter-button'),
      filterTooltip: l10n.tagFilterTooltip,
      filterLabel: args.filterState.triggerLabel(l10n),
      onFilterTap: () => _openFilterDrawer(context, args),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-tags-page-total'),
          label: l10n.tagMovieCountLabel(args.total),
        ),
      ],
      actionSlots: [
        MovieSortMenuButton(
          triggerKey: const Key('mobile-tags-sort-trigger'),
          drawerKey: const Key('mobile-tags-sort-drawer'),
          filterState: args.filterState,
          onChanged: args.onApply,
          useDrawer: true,
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

  void _confirmBrowse() {
    if (!ref.read(tagSelectionProvider(_selectionScope)).hasSelection) {
      return;
    }
    setState(() {
      _browseMode = false;
      _snapshotTagIds = null;
      _snapshotMatchMode = null;
    });
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
    setState(() {
      _browseMode = false;
      _snapshotTagIds = null;
      _snapshotMatchMode = null;
    });
  }

  void _removeTag(int tagId) {
    final notifier = ref.read(tagSelectionProvider(_selectionScope).notifier);
    notifier.remove(tagId);
    if (!ref.read(tagSelectionProvider(_selectionScope)).hasSelection) {
      setState(() {
        _browseMode = true;
        _snapshotTagIds = null;
        _snapshotMatchMode = null;
      });
    }
  }

  void _clearTags() {
    ref.read(tagSelectionProvider(_selectionScope).notifier).clear();
    setState(() {
      _browseMode = true;
      _snapshotTagIds = null;
      _snapshotMatchMode = null;
    });
  }
}
