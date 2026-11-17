import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_playlists_sliver.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_section.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_rail.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';

class MobileOverviewMyTab extends ConsumerStatefulWidget {
  const MobileOverviewMyTab({super.key});

  @override
  ConsumerState<MobileOverviewMyTab> createState() =>
      _MobileOverviewMyTabState();
}

class _MobileOverviewMyTabState extends ConsumerState<MobileOverviewMyTab> {
  static const MovieSummaryScope _latestScope = MovieSummaryScope.latest(
    pageSize: 12,
  );
  static const int _recentlySubscribedPreviewCount = 12;
  static const MovieSummaryScope _recentlySubscribedScope =
      MovieSummaryScope.recentlySubscribed();

  late final TextEditingController _searchController;
  late final PlaylistsOverviewScope _playlistsScope;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // overview 「我的」tab 按 NAS baseUrl 作 order scope，包含系统列表；
    // 与桌面 playlists 独立页共享同一份持久化顺序。
    _playlistsScope = PlaylistsOverviewScope(
      orderScopeKey: ref.read(sessionStoreProvider).baseUrl,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final latestAsync = ref.watch(movieSummaryProvider(_latestScope));
    final recentlySubscribedAsync = ref.watch(
      movieSummaryProvider(_recentlySubscribedScope),
    );

    return AppAdaptiveRefreshScrollView(
      onRefresh: _handleRefresh,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.sm),
              CatalogSearchField(
                key: const Key('mobile-overview-my-search-field'),
                fieldKey: const Key('mobile-overview-my-search-input'),
                searchButtonKey: const Key('mobile-overview-my-search-submit'),
                imageSearchButtonKey: const Key(
                  'mobile-overview-my-search-image',
                ),
                textImageSearchButtonKey: const Key(
                  'mobile-overview-my-search-text-image',
                ),
                controller: _searchController,
                hintText: l10n.overviewSearchHint,
                showImageSearchButton: ref.watch(imageSearchEnabledProvider),
                showTextImageSearchButton: ref.watch(
                  imageSearchEnabledProvider,
                ),
                onSearchTap: _submitSearch,
                onSubmitted: (_) => _submitSearch(),
                onImageSearchTap: _openImageSearch,
                onTextImageSearchTap: _openTextImageSearch,
              ),
              SizedBox(height: spacing.sm),
              if (_refreshFailed) ...<Widget>[
                AppInlineErrorBanner(
                  key: const Key('mobile-overview-refresh-error'),
                  message: l10n.overviewRefreshFailed,
                  retryKey: const Key('mobile-overview-refresh-retry'),
                  onRetry: _handleRefresh,
                ),
                SizedBox(height: spacing.sm),
              ],
              AppSectionHeader(
                title: l10n.overviewRecentlyAdded,
                actionLabel: l10n.overviewMore,
                actionSize: AppTextButtonSize.xSmall,
                actionKey: const Key('mobile-overview-latest-more'),
                onActionTap: () => MobileRoutes.latestMovies().push(context),
              ),
              SizedBox(height: spacing.xs),
              _buildLatestMoviesSection(latestAsync, l10n),
              SizedBox(height: spacing.sm),
              _buildRecentlySubscribedSection(recentlySubscribedAsync, l10n),
              _buildRecentViewsSection(),
              SizedBox(height: spacing.sm),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.overviewPlaylists,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.xs),
            ],
          ),
        ),
        MobileOverviewPlaylistsSliver(scope: _playlistsScope),
        SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
      ],
    );
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(recentViewsProvider);
    try {
      final results = await Future.wait<Object?>([
        ref.read(movieSummaryProvider(_latestScope).notifier).refresh(),
        ref
            .read(movieSummaryProvider(_recentlySubscribedScope).notifier)
            .refresh(),
        ref
            .read(playlistsOverviewProvider(_playlistsScope).notifier)
            .refresh()
            .then<Object?>((_) => null),
        ref.read(recentViewsProvider.future).then<Object?>((_) => null),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshFailed = results.any((result) => result is String);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshFailed = true;
      });
    }
  }

  Widget _buildLatestMoviesSection(
    AsyncValue<MovieSummaryState> latestAsync,
    AppLocalizations l10n,
  ) {
    final summary = latestAsync.value;
    final isLoading = latestAsync.isLoading && summary == null;
    // loading 用占位影片渲染真实卡片，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: isLoading,
      child: MovieSummaryRail(
        scrollViewKey: const Key('mobile-overview-latest-movies-list'),
        items: isLoading
            ? movieListItemPlaceholders(count: _latestScope.pageSize)
            : summary?.paged.items ?? const <MovieListItemDto>[],
        errorMessage: latestAsync.hasError && summary == null
            ? l10n.overviewLatestMoviesLoadFailed
            : null,
        onErrorRetry: () =>
            ref.read(movieSummaryProvider(_latestScope).notifier).reload(),
        emptyMessage: l10n.overviewNoLatestMovies,
        onMovieTap: (movie) => MobileRoutes.movieDetail(
          movieNumber: movie.movieNumber,
        ).push(context),
      ),
    );
  }

  Widget _buildRecentlySubscribedSection(
    AsyncValue<MovieSummaryState> async,
    AppLocalizations l10n,
  ) {
    final summary = async.value;
    final isLoading = async.isLoading && summary == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.overviewRecentlySubscribed,
          actionLabel: l10n.overviewMore,
          actionSize: AppTextButtonSize.xSmall,
          actionKey: const Key('mobile-overview-recently-subscribed-more'),
          onActionTap: () =>
              MobileRoutes.recentlySubscribedMovies().push(context),
        ),
        SizedBox(height: context.appSpacing.xs),
        // loading 用占位影片渲染真实卡片，由 [AppSkeletonizer] 灰化。
        AppSkeletonizer(
          enabled: isLoading,
          child: MovieSummaryRail(
            items: isLoading
                ? movieListItemPlaceholders(
                    count: _recentlySubscribedPreviewCount,
                  )
                : summary?.paged.items
                          .take(_recentlySubscribedPreviewCount)
                          .toList() ??
                      const <MovieListItemDto>[],
            errorMessage: async.hasError && summary == null
                ? _recentlySubscribedScope.errorText(l10n)
                : null,
            emptyMessage: l10n.overviewNoSubscribedMovies,
            onMovieTap: (movie) => MobileRoutes.movieDetail(
              movieNumber: movie.movieNumber,
            ).push(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentViewsSection() {
    return RecentViewsSection(
      spacingBefore: context.appSpacing.sm,
      actionSize: AppTextButtonSize.xSmall,
      actionKey: const Key('mobile-overview-recent-views-more'),
      onMoreTap: () => MobileRoutes.recentViews().push(context),
      onMovieTap: (movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      onActorTap: (actorId) =>
          MobileRoutes.actorDetail(actorId: actorId).push(context),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    MobileRoutes.search(query: query).push(context);
  }

  void _openTextImageSearch() {
    MobileRoutes.imageSearch(
      mode: ImageSearchInputKind.text.name,
    ).push(context);
  }

  Future<void> _openImageSearch() async {
    try {
      final pickedFile = await pickMobileImageSearchFile(
        l10n: AppLocalizations.of(context),
      );
      if (pickedFile == null || !mounted) {
        return;
      }
      final draftId = saveImageSearchDraft(
        context,
        fileName: pickedFile.fileName,
        bytes: pickedFile.bytes,
        mimeType: pickedFile.mimeType,
      );
      MobileRoutes.imageSearch(draftId: draftId).push(context);
    } on ImageSearchFilePickerException catch (error) {
      if (mounted) {
        showToast(error.message, tone: AppToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(
          ref.read(appLocalizationsProvider).overviewImagePickFailed,
          tone: AppToastTone.error,
        );
      }
    }
  }
}
