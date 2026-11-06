import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 把标签选择值显式同步到标签影片 provider。
///
/// `MovieSummaryProvider` 初次无标签时不会请求；本组件在选中标签后才应用
/// tag filter，并在后续选择/match mode 变化时重拉第一页。带预选标签的入口
/// （影片详情跳入）已由 `MovieSummaryScope.tags` 把条件带进首拉，这里的首次
/// 同步因筛选值相等而短路，不会产生第二次请求。
class TagMovieSummaryContent extends ConsumerStatefulWidget {
  const TagMovieSummaryContent({
    super.key,
    required this.selection,
    required this.scope,
    required this.surfaceColor,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.enableRefresh = false,
    this.registerPageRefresh = false,
    this.onRefreshFailure,
    this.headerBuilder,
    this.headerLeading,
    this.useMobileSelectionLayout = false,
    this.usePinnedMobileHeader = false,
  });

  final TagSelectionState selection;
  final MovieSummaryScope scope;
  final Color surfaceColor;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final MovieSummaryListBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final bool registerPageRefresh;
  final void Function(BuildContext context)? onRefreshFailure;
  final MovieSummaryListHeaderBuilder? headerBuilder;
  final Widget? headerLeading;
  final bool useMobileSelectionLayout;
  final bool usePinnedMobileHeader;

  @override
  ConsumerState<TagMovieSummaryContent> createState() =>
      _TagMovieSummaryContentState();
}

class _TagMovieSummaryContentState
    extends ConsumerState<TagMovieSummaryContent> {
  @override
  void initState() {
    super.initState();
    _scheduleTagFilterApply();
  }

  @override
  void didUpdateWidget(covariant TagMovieSummaryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
          oldWidget.selection.selectedTagIds,
          widget.selection.selectedTagIds,
        ) ||
        oldWidget.selection.matchMode != widget.selection.matchMode) {
      _scheduleTagFilterApply();
    }
  }

  void _scheduleTagFilterApply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyTagFilter();
      }
    });
  }

  void _applyTagFilter() {
    if (!mounted || !widget.selection.hasSelection) {
      return;
    }
    unawaited(
      ref
          .read(movieSummaryProvider(widget.scope).notifier)
          .applyTagFilter(
            tagIds: widget.selection.selectedTagIds,
            tagMatch: widget.selection.matchMode,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MovieSummaryListContent(
      scope: widget.scope,
      surfaceColor: widget.surfaceColor,
      contentKey: widget.contentKey,
      totalKey: widget.totalKey,
      sectionSpacing: widget.sectionSpacing,
      emptyMessage: AppLocalizations.of(context).tagEmptyMovieList,
      enableRefresh: widget.enableRefresh,
      registerPageRefresh: widget.registerPageRefresh,
      onRefreshFailure: widget.onRefreshFailure,
      headerBuilder: widget.headerBuilder,
      headerLeading: widget.headerLeading,
      useMobileSelectionLayout: widget.useMobileSelectionLayout,
      usePinnedMobileHeader: widget.usePinnedMobileHeader,
      onMovieTap: widget.onMovieTap,
      bodyBuilder: widget.bodyBuilder,
    );
  }
}
