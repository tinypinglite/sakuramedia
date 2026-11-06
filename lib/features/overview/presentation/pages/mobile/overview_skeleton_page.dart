import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/overview_clips_tab.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/moments/presentation/pages/mobile/overview_moments_tab.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_section.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_rail.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';

class MobileOverviewSkeletonPage extends StatelessWidget {
  const MobileOverviewSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: _MobileOverviewTabIndexReporter(
        child: Column(
          key: const Key('mobile-overview-skeleton-page'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileOverviewHeader(),
            Expanded(
              child: TabBarView(
                key: const Key('mobile-overview-tab-view'),
                children: const [
                  AppKeepAlive(child: _MobileOverviewMyTab()),
                  AppKeepAlive(child: MobileOverviewClipsTab()),
                  AppKeepAlive(child: MobileOverviewDiscoverTab()),
                  AppKeepAlive(child: MobileOverviewMomentsTab()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把当前 tab 序号上报给壳层,壳据此决定是否放开左边缘侧滑打开抽屉。
/// 见 [mobileOverviewTabIndexProvider]。
class _MobileOverviewTabIndexReporter extends ConsumerStatefulWidget {
  const _MobileOverviewTabIndexReporter({required this.child});

  final Widget child;

  @override
  ConsumerState<_MobileOverviewTabIndexReporter> createState() =>
      _MobileOverviewTabIndexReporterState();
}

class _MobileOverviewTabIndexReporterState
    extends ConsumerState<_MobileOverviewTabIndexReporter> {
  TabController? _controller;
  MobileOverviewTabIndex? _notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 这里 read 拿 notifier 实例,build 里的 watch(.notifier) 负责持有订阅、
    // 防止 autoDispose 提前释放。
    _notifier ??= ref.read(mobileOverviewTabIndexProvider.notifier);
    final controller = DefaultTabController.maybeOf(context);
    if (identical(controller, _controller)) {
      return;
    }
    _controller?.removeListener(_report);
    _controller = controller?..addListener(_report);
    // 这里仍在 build 期,直接写 provider 会 markNeedsBuild 正在构建中的祖先(壳
    // builder watch 着它),抛「setState() called during build」。挂载时的首次对齐
    // 推迟到本帧结束;之后的变更都由 TabController 回调驱动,那本就在 build 之外。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _report();
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_report);
    super.dispose();
  }

  void _report() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    // 相同 state Riverpod Notifier 按 == 去重不通知,拖动动画期间的每帧回调
    // 不会引起重建。
    _notifier?.report(controller.index);
  }

  @override
  Widget build(BuildContext context) {
    // 持有对 autoDispose provider 的订阅，防止 notifier 在壳未 watch 的
    // 间隙被释放；watch `.notifier` 不随 value 变化重建。
    ref.watch(mobileOverviewTabIndexProvider.notifier);
    return widget.child;
  }
}

class _MobileOverviewHeader extends StatelessWidget {
  const _MobileOverviewHeader();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: SizedBox(
        height: componentTokens.mobileTopTabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
              builder: (buttonContext) {
                return Center(
                  child: AppGlassIconButton(
                    key: const Key('mobile-overview-menu-button'),
                    tooltip: l10n.overviewOpenMenu,
                    semanticLabel: l10n.overviewOpenMenu,
                    icon: Icons.menu_rounded,
                    // 不能在 build 期把 hasDrawer 快照下来当门控:Scaffold.maybeOf
                    // 走 findAncestorStateOfType,不建立依赖,drawer 后来挂上也不会
                    // 触发本页重建,按钮会永久停在禁用态。改为点击时现取,
                    // openDrawer 内部对无 drawer 的情况是 null-safe 的。
                    onPressed: () =>
                        Scaffold.maybeOf(buttonContext)?.openDrawer(),
                  ),
                );
              },
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: AppTabBar(
                variant: AppTabBarVariant.mobileTop,
                key: const Key('mobile-overview-tabs'),
                tabs: [
                  Tab(text: l10n.overviewTabMine),
                  Tab(text: l10n.overviewTabClips),
                  Tab(text: l10n.overviewTabDiscover),
                  Tab(text: l10n.overviewTabMoments),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileOverviewMyTab extends ConsumerStatefulWidget {
  const _MobileOverviewMyTab();

  @override
  ConsumerState<_MobileOverviewMyTab> createState() =>
      _MobileOverviewMyTabState();
}

class _MobileOverviewMyTabState extends ConsumerState<_MobileOverviewMyTab> {
  static const int _latestMoviePageSize = 12;
  static const int _recentlySubscribedPreviewCount = 12;
  static const _recentlySubscribedScope =
      MovieSummaryScope.recentlySubscribed();

  late final TextEditingController _searchController;
  late final PlaylistsOverviewScope _playlistsScope;
  bool _isLoadingLatestMovies = true;
  String? _latestMoviesErrorMessage;
  List<MovieListItemDto> _latestMovies = const <MovieListItemDto>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // overview 「我的」tab 按 NAS baseUrl 作 order scope，包含系统列表；
    // 与桌面 playlists 独立页共享同一份持久化顺序。
    _playlistsScope = PlaylistsOverviewScope(
      orderScopeKey: ref.read(sessionStoreProvider).baseUrl,
    );
    _loadLatestMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestMovies() async {
    setState(() {
      _isLoadingLatestMovies = true;
      _latestMoviesErrorMessage = null;
    });

    try {
      final response = await ref
          .read(moviesApiProvider)
          .getLatestMovies(page: 1, pageSize: _latestMoviePageSize);
      if (!mounted) {
        return;
      }
      setState(() {
        _latestMovies = response.items;
        _latestMoviesErrorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _latestMovies = const <MovieListItemDto>[];
        _latestMoviesErrorMessage = ref
            .read(appLocalizationsProvider)
            .overviewLatestMoviesLoadFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingLatestMovies = false);
      }
    }
  }

  void _handlePlaylistReorderStart(int _) {
    unawaited(
      HapticFeedback.mediumImpact().catchError((Object _) {
        return;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);

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
              AppSectionHeader(
                title: l10n.overviewRecentlyAdded,
                actionLabel: l10n.overviewMore,
                actionSize: AppTextButtonSize.xSmall,
                actionKey: const Key('mobile-overview-latest-more'),
                onActionTap: () =>
                    const MobileLatestMoviesRouteData().push(context),
              ),
              SizedBox(height: spacing.xs),
              _buildLatestMoviesSection(),
              SizedBox(height: spacing.sm),
              _buildRecentlySubscribedSection(),
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
        _buildPlaylistsSliver(),
        SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
      ],
    );
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(recentViewsProvider);
    try {
      await Future.wait<void>([
        _refreshLatestMovies(),
        ref
            .read(movieSummaryProvider(_recentlySubscribedScope).notifier)
            .refresh(),
        ref.read(playlistsOverviewProvider(_playlistsScope).notifier).refresh(),
        // invalidate 的「最近浏览」要等重建完成，否则刷新指示器先于
        // rail 重载结束，rail 里还是旧快照。
        ref.read(recentViewsProvider.future).then<void>((_) {}),
      ]);
    } catch (_) {
      if (mounted) {
        showToast(
          AppLocalizations.of(context).overviewRefreshFailed,
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _refreshLatestMovies() async {
    final response = await ref
        .read(moviesApiProvider)
        .getLatestMovies(page: 1, pageSize: _latestMoviePageSize);
    if (!mounted) {
      return;
    }
    setState(() {
      _latestMovies = response.items;
      _latestMoviesErrorMessage = null;
    });
  }

  Widget _buildLatestMoviesSection() {
    // loading 用占位影片渲染真实卡片，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: _isLoadingLatestMovies,
      child: MovieSummaryRail(
        scrollViewKey: const Key('mobile-overview-latest-movies-list'),
        items: _isLoadingLatestMovies
            ? movieListItemPlaceholders(count: _latestMoviePageSize)
            : _latestMovies,
        errorMessage: _latestMoviesErrorMessage,
        onErrorRetry: _loadLatestMovies,
        emptyMessage: AppLocalizations.of(context).overviewNoLatestMovies,
        onMovieTap: (movie) => MobileMovieDetailRouteData(
          movieNumber: movie.movieNumber,
        ).push(context),
      ),
    );
  }

  Widget _buildRecentlySubscribedSection() {
    final async = ref.watch(movieSummaryProvider(_recentlySubscribedScope));
    final summary = async.value;
    final isLoading = async.isLoading && summary == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: AppLocalizations.of(context).overviewRecentlySubscribed,
          actionLabel: AppLocalizations.of(context).overviewMore,
          actionSize: AppTextButtonSize.xSmall,
          actionKey: const Key('mobile-overview-recently-subscribed-more'),
          onActionTap: () =>
              const MobileRecentlySubscribedMoviesRouteData().push(context),
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
                ? _recentlySubscribedScope.errorText(
                    AppLocalizations.of(context),
                  )
                : null,
            emptyMessage: AppLocalizations.of(
              context,
            ).overviewNoSubscribedMovies,
            onMovieTap: (movie) => MobileMovieDetailRouteData(
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
      onMoreTap: () => const MobileRecentViewsRouteData().push(context),
      onMovieTap: (movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      onActorTap: (actorId) =>
          MobileActorDetailRouteData(actorId: actorId).push(context),
    );
  }

  Widget _buildPlaylistsSliver() {
    return Consumer(
      builder: (context, ref, _) {
        final overview = ref.watch(
          playlistsOverviewProvider(
            _playlistsScope,
          ).select(selectPlaylistsOverview),
        );
        if (overview.isLoading) {
          return SliverToBoxAdapter(child: _buildPlaylistsSkeleton());
        }
        if (overview.error case final error?) {
          final l10n = AppLocalizations.of(context);
          return SliverToBoxAdapter(
            child: AppEmptyState(
              message: apiErrorMessage(
                error,
                fallback: l10n.overviewPlaylistsLoadFailed,
                l10n: l10n,
              ),
            ),
          );
        }
        final playlists = overview.playlists;
        if (playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: AppEmptyState(
              message: AppLocalizations.of(context).overviewNoPlaylists,
            ),
          );
        }

        return SliverReorderableList(
          key: const Key('mobile-overview-playlists-list'),
          itemCount: playlists.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<int>) {
              return null;
            }
            final index = playlists.indexWhere(
              (playlist) => playlist.id == key.value,
            );
            return index < 0 ? null : index;
          },
          onReorderItem: ref
              .read(playlistsOverviewProvider(_playlistsScope).notifier)
              .reorderPlaylists,
          onReorderStart: _handlePlaylistReorderStart,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ReorderableDelayedDragStartListener(
              key: ValueKey<int>(playlist.id),
              index: index,
              child: Padding(
                padding: EdgeInsets.only(bottom: context.appSpacing.sm),
                child: _buildPlaylistBanner(context, playlist),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistBanner(BuildContext context, PlaylistDto playlist) {
    return Consumer(
      builder: (context, ref, _) {
        final coverImageUrl = ref.watch(
          playlistsOverviewProvider(
            _playlistsScope,
          ).select((async) => async.value?.coverUrlFor(playlist.id)),
        );
        return PlaylistBannerCard(
          key: Key('mobile-overview-playlist-${playlist.id}'),
          title: playlist.name,
          coverImageUrl: coverImageUrl,
          onTap: () => MobilePlaylistDetailRouteData(
            playlistId: playlist.id,
          ).push(context),
        );
      },
    );
  }

  Widget _buildPlaylistsSkeleton() {
    final spacing = context.appSpacing;
    // loading 用占位播放列表渲染真实横幅，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        children: [
          for (var index = 0; index < 6; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            PlaylistBannerCard(title: BoneMock.words(2), coverImageUrl: null),
          ],
        ],
      ),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    MobileSearchQueryRouteData(query: query).push(context);
  }

  void _openTextImageSearch() {
    context.pushMobileImageSearch(initialInputKind: ImageSearchInputKind.text);
  }

  Future<void> _openImageSearch() async {
    try {
      final pickedFile = await pickMobileImageSearchFile(
        l10n: AppLocalizations.of(context),
      );
      if (pickedFile == null || !mounted) {
        return;
      }
      context.pushMobileImageSearch(
        initialFileName: pickedFile.fileName,
        initialFileBytes: pickedFile.bytes,
        initialMimeType: pickedFile.mimeType,
      );
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
