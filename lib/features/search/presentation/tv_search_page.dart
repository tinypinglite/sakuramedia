import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/tv/tv_action_button.dart';
import 'package:sakuramedia/widgets/base/tv/tv_actor_card.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_grid.dart';
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
    return TvPagePadding(
      child: Column(
        key: const Key('tv-search-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvPageHeader(title: l10n.routeSearchTitle),
          SizedBox(height: context.appSpacing.xl),
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
                  height: AppTvTokens.navHeight,
                ),
              ),
              SizedBox(width: context.appSpacing.md),
              TvActionButton(
                key: const Key('tv-search-submit'),
                label: l10n.routeSearchTitle,
                icon: Icons.search_rounded,
                onPressed: _submit,
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Row(
            children: [
              _TvSearchKindChip(
                label: l10n.routeMoviesTitle,
                selected: state.activeKind == CatalogSearchKind.movies,
                onPressed: () => ref
                    .read(catalogSearchProvider(_scope).notifier)
                    .setActiveKind(CatalogSearchKind.movies),
              ),
              SizedBox(width: context.appSpacing.md),
              _TvSearchKindChip(
                label: l10n.routeActorsTitle,
                selected: state.activeKind == CatalogSearchKind.actors,
                onPressed: () => ref
                    .read(catalogSearchProvider(_scope).notifier)
                    .setActiveKind(CatalogSearchKind.actors),
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.xl),
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
      return Center(
        child: Text(
          state.errorMessage!,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            tone: AppTextTone.error,
          ),
        ),
      );
    }
    if (state.activeKind == CatalogSearchKind.actors) {
      return _buildActorResults(context, state);
    }
    final movies = state.movieResults;
    if (movies.isEmpty) {
      return Center(
        child: Text(
          state.query.isEmpty
              ? l10n.widgetSearchHint
              : l10n.widgetSearchLocalNoMovies,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s24,
            tone: AppTextTone.secondary,
          ),
        ),
      );
    }
    return TvMovieGrid(
      items: movies,
      onPressed: (movie) =>
          TvRoutes.movieDetail(movieNumber: movie.movieNumber).push(context),
    );
  }

  Widget _buildActorResults(BuildContext context, CatalogSearchState state) {
    final l10n = AppLocalizations.of(context);
    final actors = state.actorResults;
    if (actors.isEmpty) {
      return Center(
        child: Text(
          state.query.isEmpty
              ? l10n.widgetSearchHint
              : l10n.widgetSearchLocalNoActors,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s24,
            tone: AppTextTone.secondary,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppTvTokens.gridColumnsForWidth(constraints.maxWidth);
        final availableWidth =
            constraints.maxWidth - AppTvTokens.gridGap * (columns - 1);
        final cardWidth = availableWidth / columns;
        final cardHeight = cardWidth / 0.752;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(
            vertical: AppTvTokens.focusOverflow,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppTvTokens.gridGap,
            mainAxisSpacing: AppTvTokens.gridGap,
            mainAxisExtent: cardHeight + AppTvTokens.focusOverflow * 2,
          ),
          itemCount: actors.length,
          itemBuilder: (context, index) {
            final actor = actors[index];
            return Align(
              alignment: Alignment.topCenter,
              child: TvActorCard(
                actor: actor,
                width: cardWidth,
                height: cardHeight,
                onPressed: () => _openActorMovies(context, actor),
              ),
            );
          },
        );
      },
    );
  }

  void _openActorMovies(BuildContext context, ActorListItemDto actor) {
    TvRoutes.actorMovies(
      actorId: actor.id,
      actorName: actor.displayName,
    ).push(context);
  }
}

class _TvSearchKindChip extends StatelessWidget {
  const _TvSearchKindChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.pillBorder,
      scale: 1.02,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xl,
          vertical: context.appSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.surfaceElevated,
          borderRadius: context.appRadius.pillBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: selected ? AppTextWeight.semibold : AppTextWeight.regular,
            tone: selected ? AppTextTone.onMedia : AppTextTone.primary,
          ),
        ),
      ),
    );
  }
}
