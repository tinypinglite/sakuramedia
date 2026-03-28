import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/mobile_overview_hot_reviews_tab.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_follow_tab.dart';
import 'package:sakuramedia/features/moments/presentation/mobile_overview_moments_tab.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/playlists_overview_controller.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';
import 'package:sakuramedia/widgets/search/catalog_search_field.dart';

class MobileOverviewSkeletonPage extends StatelessWidget {
  const MobileOverviewSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DefaultTabController(
      length: 5,
      child: ColoredBox(
        key: const Key('mobile-overview-skeleton-page'),
        color: colors.surfaceCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileOverviewHeader(),
            Expanded(
              child: TabBarView(
                key: const Key('mobile-overview-tab-view'),
                children: const [
                  _MobileOverviewMyTab(),
                  MobileOverviewFollowTab(),
                  _MobileOverviewDiscoverTab(),
                  MobileOverviewMomentsTab(),
                  MobileOverviewHotReviewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileOverviewHeader extends StatelessWidget {
  const _MobileOverviewHeader();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: SizedBox(
        height: componentTokens.mobileTopTabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
              builder: (buttonContext) {
                final scaffold = Scaffold.maybeOf(buttonContext);
                final canOpenDrawer = scaffold?.hasDrawer ?? false;
                return Center(
                  child: AppIconButton(
                    key: const Key('mobile-overview-menu-button'),
                    tooltip: '打开菜单',
                    semanticLabel: '打开菜单',
                    size: AppIconButtonSize.regular,
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: canOpenDrawer ? scaffold!.openDrawer : null,
                  ),
                );
              },
            ),
            SizedBox(width: spacing.xs),
            const Expanded(
              child: AppTabBar(
                key: Key('mobile-overview-tabs'),
                variant: AppTabBarVariant.mobileTop,
                tabs: [
                  Tab(text: '我的'),
                  Tab(text: '关注'),
                  Tab(text: '发现'),
                  Tab(text: '时刻'),
                  Tab(text: '热评'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileOverviewMyTab extends StatefulWidget {
  const _MobileOverviewMyTab();

  @override
  State<_MobileOverviewMyTab> createState() => _MobileOverviewMyTabState();
}

class _MobileOverviewMyTabState extends State<_MobileOverviewMyTab> {
  static const int _latestMoviePageSize = 12;

  late final TextEditingController _searchController;
  late final PlaylistsOverviewController _playlistsController;
  bool _isLoadingLatestMovies = true;
  String? _latestMoviesErrorMessage;
  List<MovieListItemDto> _latestMovies = const <MovieListItemDto>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final playlistsApi = context.read<PlaylistsApi>();
    _playlistsController = PlaylistsOverviewController(
      fetchPlaylists: playlistsApi.getPlaylists,
      fetchPlaylistCoverUrl: (playlistId) async {
        final page = await playlistsApi.getPlaylistMovies(
          playlistId: playlistId,
          pageSize: 1,
        );
        return page.items.firstOrNull?.coverImage?.bestAvailableUrl;
      },
      createPlaylist: playlistsApi.createPlaylist,
    )..load();
    _loadLatestMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _playlistsController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestMovies() async {
    setState(() {
      _isLoadingLatestMovies = true;
      _latestMoviesErrorMessage = null;
    });

    try {
      final response = await context.read<MoviesApi>().getLatestMovies(
        page: 1,
        pageSize: _latestMoviePageSize,
      );
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
        _latestMoviesErrorMessage = '最近添加影片加载失败，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingLatestMovies = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.sm),
          CatalogSearchField(
            key: const Key('mobile-overview-my-search-field'),
            fieldKey: const Key('mobile-overview-my-search-input'),
            searchButtonKey: const Key('mobile-overview-my-search-submit'),
            imageSearchButtonKey: const Key('mobile-overview-my-search-image'),
            controller: _searchController,
            hintText: '找影片',
            showImageSearchButton: true,
            onSearchTap: _submitSearch,
            onSubmitted: (_) => _submitSearch(),
            onImageSearchTap: _openImageSearch,
          ),
          SizedBox(height: spacing.sm),
          Text('最近添加', style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: spacing.xs),
          _buildLatestMoviesSection(),
          SizedBox(height: spacing.sm),
          Text('播放列表', style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: spacing.xs),
          _buildPlaylistsSection(),
        ],
      ),
    );
  }

  Widget _buildLatestMoviesSection() {
    if (_isLoadingLatestMovies) {
      return _buildLatestMoviesSkeleton();
    }
    if (_latestMoviesErrorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppEmptyState(message: _latestMoviesErrorMessage!),
          TextButton(onPressed: _loadLatestMovies, child: const Text('重试')),
        ],
      );
    }
    if (_latestMovies.isEmpty) {
      return const AppEmptyState(message: '暂无最近添加影片');
    }

    final cardWidth = context.appComponentTokens.mobileLatestMovieCardWidth;
    final cardHeight =
        cardWidth / context.appComponentTokens.movieCardAspectRatio;

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        key: const Key('mobile-overview-latest-movies-list'),
        scrollDirection: Axis.horizontal,
        itemCount: _latestMovies.length,
        separatorBuilder:
            (context, index) => SizedBox(width: context.appSpacing.sm),
        itemBuilder: (context, index) {
          final movie = _latestMovies[index];
          return SizedBox(
            width: cardWidth,
            child: MovieSummaryCard(
              movie: movie,
              onTap:
                  () => MobileMovieDetailRouteData(
                    movieNumber: movie.movieNumber,
                  ).push(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestMoviesSkeleton() {
    final cardWidth = context.appComponentTokens.mobileLatestMovieCardWidth;
    final cardHeight =
        cardWidth / context.appComponentTokens.movieCardAspectRatio;
    final colors = context.appColors;

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder:
            (context, index) => SizedBox(width: context.appSpacing.sm),
        itemBuilder:
            (context, index) => Container(
              width: cardWidth,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.appRadius.lgBorder,
              ),
            ),
      ),
    );
  }

  Widget _buildPlaylistsSection() {
    return AnimatedBuilder(
      animation: _playlistsController,
      builder: (context, _) {
        if (_playlistsController.isLoading) {
          return _buildPlaylistsSkeleton();
        }
        if (_playlistsController.errorMessage != null) {
          return AppEmptyState(message: _playlistsController.errorMessage!);
        }
        if (_playlistsController.playlists.isEmpty) {
          return const AppEmptyState(message: '暂无播放列表');
        }

        return Column(
          key: const Key('mobile-overview-playlists-list'),
          children: _playlistsController.playlists
              .map(
                (playlist) => Padding(
                  padding: EdgeInsets.only(bottom: context.appSpacing.sm),
                  child: PlaylistBannerCard(
                    key: Key('mobile-overview-playlist-${playlist.id}'),
                    title: playlist.name,
                    coverImageUrl: _playlistsController.coverUrlFor(
                      playlist.id,
                    ),
                    onTap:
                        () => MobilePlaylistDetailRouteData(
                          playlistId: playlist.id,
                        ).push(context),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildPlaylistsSkeleton() {
    final colors = context.appColors;
    final radius = context.appRadius;
    final height = context.appComponentTokens.playlistBannerHeight;

    return Column(
      children: List<Widget>.generate(2, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: radius.lgBorder,
            ),
          ),
        );
      }),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }
    MobileSearchQueryRouteData(query: query).push(context);
  }

  Future<void> _openImageSearch() async {
    try {
      final pickedFile = await pickMobileImageSearchFile();
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
        showToast(error.message);
      }
    } catch (_) {
      if (mounted) {
        showToast('选择图片失败');
      }
    }
  }
}

class _MobileOverviewDiscoverTab extends StatelessWidget {
  const _MobileOverviewDiscoverTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppEmptyState(message: '开发中'));
  }
}
