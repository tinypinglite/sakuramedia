import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/tv/tv_actor_card.dart';
import 'package:sakuramedia/widgets/base/tv/tv_card_grid.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

class TvSearchPage extends ConsumerStatefulWidget {
  const TvSearchPage({super.key});

  @override
  ConsumerState<TvSearchPage> createState() => _TvSearchPageState();
}

class _TvSearchPageState extends ConsumerState<TvSearchPage> {
  static const _scope = CatalogSearchScope('tv:search');

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'tv-search');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(catalogSearchProvider(_scope).notifier)
          .bootstrap(initialQuery: '', initialUseOnlineSearch: false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    await ref
        .read(catalogSearchProvider(_scope).notifier)
        .submit(query, useOnlineSearch: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogSearchProvider(_scope));
    final spacing = context.appSpacing;
    return TvPagePadding(
      child: Column(
        key: const Key('tv-search-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvPageHeader(title: l10n.routeSearchTitle),
          SizedBox(height: spacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  fieldKey: const Key('tv-search-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  label: l10n.routeSearchTitle,
                  hintText: l10n.widgetSearchHint,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => unawaited(_submit()),
                  borderRadius: context.appRadius.mdBorder,
                  height: AppTvTokens.controlHeight,
                  style: resolveAppTextStyle(context, size: AppTextSize.s18),
                ),
              ),
              SizedBox(width: spacing.md),
              AppButton(
                key: const Key('tv-search-submit'),
                label: l10n.routeSearchTitle,
                icon: const Icon(Icons.search_rounded),
                size: AppButtonSize.tvLarge,
                variant: AppButtonVariant.primary,
                onPressed: _submit,
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Row(
            spacing: spacing.md,
            children: [
              AppFilterChip(
                label: l10n.routeMoviesTitle,
                selected: state.activeKind == CatalogSearchKind.movies,
                selectionStyle: AppFilterChipSelectionStyle.accent,
                onPressed: () => ref
                    .read(catalogSearchProvider(_scope).notifier)
                    .setActiveKind(CatalogSearchKind.movies),
              ),
              AppFilterChip(
                label: l10n.routeActorsTitle,
                selected: state.activeKind == CatalogSearchKind.actors,
                selectionStyle: AppFilterChipSelectionStyle.accent,
                onPressed: () => ref
                    .read(catalogSearchProvider(_scope).notifier)
                    .setActiveKind(CatalogSearchKind.actors),
              ),
            ],
          ),
          SizedBox(height: spacing.xl),
          Expanded(child: _buildResults(context, state)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, CatalogSearchState state) {
    final l10n = AppLocalizations.of(context);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return AppErrorState(
        title: l10n.baseActionFailed,
        message: state.errorMessage!,
      );
    }
    if (state.activeKind == CatalogSearchKind.actors) {
      return _buildActorResults(context, state);
    }
    final movies = state.movieResults;
    if (movies.isEmpty) {
      return AppEmptyState(
        message: state.query.isEmpty
            ? l10n.widgetSearchHint
            : l10n.widgetSearchLocalNoMovies,
      );
    }
    return TvCardGrid<MovieListItemDto>(
      gridKey: const Key('tv-movie-grid'),
      items: movies,
      itemBuilder: (context, movie) => TvMovieCard(
        movie: movie,
        onPressed: () =>
            TvRoutes.movieDetail(movieNumber: movie.movieNumber).push(context),
      ),
    );
  }

  Widget _buildActorResults(BuildContext context, CatalogSearchState state) {
    final l10n = AppLocalizations.of(context);
    final actors = state.actorResults;
    if (actors.isEmpty) {
      return AppEmptyState(
        message: state.query.isEmpty
            ? l10n.widgetSearchHint
            : l10n.widgetSearchLocalNoActors,
      );
    }
    return TvCardGrid<ActorListItemDto>(
      gridKey: const Key('tv-actor-grid'),
      items: actors,
      itemBuilder: (context, actor) => TvActorCard(
        actor: actor,
        onPressed: () => TvRoutes.actorMovies(
          actorId: actor.id,
          actorName: actor.displayName,
        ).push(context),
      ),
    );
  }
}
