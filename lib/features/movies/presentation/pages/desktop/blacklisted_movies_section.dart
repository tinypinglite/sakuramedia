import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

enum _BlacklistedMovieAction { unblacklist }

/// 系统设置「屏蔽影片」分类页：自持滚动容器，滚到底自动加载下一页
/// （与其它列表页同一套 `AppPagedLoadMoreScope`）。
class BlacklistedMoviesSection extends HookConsumerWidget {
  const BlacklistedMoviesSection({super.key, required this.active});

  /// 分类页是否可见；非活跃时不订阅列表，也不响应滚动加载。
  final bool active;

  static const _scope = MovieSummaryScope.blacklisted();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 首次可见后常驻（IndexedStack 保活），未打开过时不建订阅。
    final activated = useRef(active);
    if (active) {
      activated.value = true;
    }
    final scrollController = useScrollController();
    if (!activated.value) {
      return const SizedBox.shrink();
    }

    final content = _buildContent(context, ref, scrollController);
    return active
        ? AppPageRefreshScope(
            onRefresh: () =>
                ref.read(movieSummaryProvider(_scope).notifier).reload(),
            child: content,
          )
        : content;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(
      movieSummaryProvider(
        _scope,
      ).select((async) => pagedViewSnapshot(async, (state) => state.paged)),
    );
    final isLoading = view.isInitialLoading;
    final slivers = <Widget>[];

    if (view.initialError case final error?) {
      slivers.add(
        SliverToBoxAdapter(
          child: AppSectionError(
            title: l10n.moviePageBlacklistLoadFailedTitle,
            message: apiErrorMessage(
              error,
              fallback: l10n.moviePageBlacklistLoadFailed,
              l10n: l10n,
            ),
            onRetry: () =>
                ref.read(movieSummaryProvider(_scope).notifier).reload(),
          ),
        ),
      );
    } else {
      // loading 用占位影片渲染真实海报网格，由 [AppSkeletonizer] 灰化。
      slivers.addAll(<Widget>[
        SliverToBoxAdapter(
          child: Text(
            l10n.moviePageBlacklistHint,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
        MovieSummarySliver(
          items: isLoading ? movieListItemPlaceholders() : view.items,
          emptyMessage: l10n.moviePageBlacklistEmpty,
          onMovieTap: (movie) => DesktopRoutes.movieDetail(
            movieNumber: movie.movieNumber,
            fallbackPath: desktopMoviesPath,
          ).push(context),
          onMovieMenuRequest: (movie, position) =>
              _showMovieActions(context, ref, movie, position),
        ),
        // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
        PagedLoadMoreFooterSliver(
          topSpacing: PagedFooterSpacing.lg,
          watchFooter: (ref) => ref.watch(
            movieSummaryProvider(
              _scope,
            ).select((s) => pagedLoadMoreFooterSnapshot(s.value?.paged)),
          ),
          onLoadMore: (ref) => unawaited(
            ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
          ),
        ),
      ]);
    }

    return AppPagedLoadMoreScope(
      enabled: active,
      canLoadMore: () =>
          ref.read(movieSummaryProvider(_scope)).value?.paged.canAutoLoadMore ??
          false,
      onLoadMore: () =>
          ref.read(movieSummaryProvider(_scope).notifier).loadMore(),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          AppSkeletonizer.sliver(
            enabled: isLoading,
            child: SliverPadding(
              // 与系统设置其它分类页一致的内边距（右侧 + 底部）。
              padding: EdgeInsets.only(right: spacing.lg, bottom: spacing.xxl),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unblacklistMovie(
    BuildContext context,
    WidgetRef ref,
    MovieListItemDto movie,
  ) async {
    try {
      await ref
          .read(movieSummaryProvider(_scope).notifier)
          .unblacklistMovie(movieNumber: movie.movieNumber);
    } catch (error) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageUnblacklistFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return;
    }
    if (context.mounted) {
      showToast(
        AppLocalizations.of(context).moviePageUnblacklisted,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _showMovieActions(
    BuildContext context,
    WidgetRef ref,
    MovieListItemDto movie,
    Offset globalPosition,
  ) async {
    final action = await showAppActionMenu<_BlacklistedMovieAction>(
      context: context,
      globalPosition: globalPosition,
      items: <AppMenuItem<_BlacklistedMovieAction>>[
        AppMenuItem(
          value: _BlacklistedMovieAction.unblacklist,
          label: AppLocalizations.of(context).moviePageUnblacklistAction,
        ),
      ],
    );
    if (action == _BlacklistedMovieAction.unblacklist && context.mounted) {
      await _unblacklistMovie(context, ref, movie);
    }
  }
}
