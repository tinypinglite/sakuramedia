import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_action_button.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_grid.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

class TvMovieSummaryGridPage extends ConsumerStatefulWidget {
  const TvMovieSummaryGridPage({
    super.key,
    required this.scope,
    required this.title,
    required this.pageKey,
  });

  final MovieSummaryScope scope;
  final String title;
  final Key pageKey;

  @override
  ConsumerState<TvMovieSummaryGridPage> createState() =>
      _TvMovieSummaryGridPageState();
}

class _TvMovieSummaryGridPageState
    extends ConsumerState<TvMovieSummaryGridPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 900) {
      return;
    }
    final state = ref.read(movieSummaryProvider(widget.scope)).value;
    if (state?.paged.canAutoLoadMore ?? false) {
      unawaited(
        ref.read(movieSummaryProvider(widget.scope).notifier).loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(movieSummaryProvider(widget.scope));
    final state = async.value;
    final items = state?.paged.items ?? const <MovieListItemDto>[];
    return TvPagePadding(
      child: Column(
        key: widget.pageKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvPageHeader(
            title: widget.title,
            subtitle: state == null
                ? null
                : l10n.moviePageMovieCount(state.paged.total),
          ),
          SizedBox(height: context.appSpacing.xl),
          Expanded(
            child: switch ((async.isLoading, async.hasError, items.isEmpty)) {
              (true, _, true) => const Center(
                child: CircularProgressIndicator(),
              ),
              (false, true, true) => _TvMoviesError(
                message: l10n.errorMovieListLoadFailed,
                onRetry: () =>
                    ref.invalidate(movieSummaryProvider(widget.scope)),
              ),
              (_, _, true) => _TvMoviesError(
                message: l10n.widgetMovieEmptyList,
                onRetry: () =>
                    ref.invalidate(movieSummaryProvider(widget.scope)),
              ),
              _ => TvMovieGrid(
                items: items,
                controller: _scrollController,
                onPressed: (movie) => TvRoutes.movieDetail(
                  movieNumber: movie.movieNumber,
                ).push(context),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _TvMoviesError extends StatelessWidget {
  const _TvMoviesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s24,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: context.appSpacing.xl),
          TvActionButton(
            label: l10n.commonRetry,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
