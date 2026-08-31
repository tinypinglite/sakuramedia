import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/overview_clips_tab.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/pages/mobile/overview_hot_reviews_tab.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/moments/presentation/pages/mobile/overview_moments_tab.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';

class MobileOverviewSkeletonPage extends StatelessWidget {
  const MobileOverviewSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DefaultTabController(
      length: 5,
      child: _MobileOverviewTabIndexReporter(
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
                    MobileOverviewClipsTab(),
                    MobileOverviewDiscoverTab(),
                    MobileOverviewMomentsTab(),
                    MobileOverviewHotReviewsTab(),
                  ],
                ),
              ),
            ],
          ),
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
                  child: AppIconButton(
                    key: const Key('mobile-overview-menu-button'),
                    tooltip: '打开菜单',
                    semanticLabel: '打开菜单',
                    // compact 的命中区只有 28dp,低于触控最小目标,手指略偏就落空
                    // (「有时点不动」)。regular = 20 + md*2 = 44dp,图标视觉不变。
                    size: AppIconButtonSize.regular,
                    icon: const Icon(Icons.menu_rounded),
                    // 不能在 build 期把 hasDrawer 快照下来当门控:Scaffold.maybeOf
                    // 走 findAncestorStateOfType,不建立依赖,drawer 后来挂上也不会
                    // 触发本页重建,按钮会永久停在禁用态。改为点击时现取,
                    // openDrawer 内部对无 drawer 的情况是 null-safe 的。
                    onPressed:
                        () => Scaffold.maybeOf(buttonContext)?.openDrawer(),
                  ),
                );
              },
            ),
            SizedBox(width: spacing.xs),
            const Expanded(
              child: AppTabBar(
                variant: AppTabBarVariant.mobileTop,
                key: Key('mobile-overview-tabs'),
                tabs: [
                  Tab(text: '我的'),
                  Tab(text: '切片'),
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

class _MobileOverviewMyTab extends ConsumerStatefulWidget {
  const _MobileOverviewMyTab();

  @override
  ConsumerState<_MobileOverviewMyTab> createState() =>
      _MobileOverviewMyTabState();
}

class _MobileOverviewMyTabState extends ConsumerState<_MobileOverviewMyTab> {
  static const int _latestMoviePageSize = 12;

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
        _latestMoviesErrorMessage = '最近添加影片加载失败，请稍后重试';
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
                controller: _searchController,
                hintText: '如 SSNI-888、三上悠亚',
                showImageSearchButton: true,
                onSearchTap: _submitSearch,
                onSubmitted: (_) => _submitSearch(),
                onImageSearchTap: _openImageSearch,
              ),
              SizedBox(height: spacing.sm),
              Text(
                '最近添加',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.xs),
              _buildLatestMoviesSection(),
              SizedBox(height: spacing.sm),
              Text(
                '播放列表',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.xs),
              _buildPlaylistsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        _refreshLatestMovies(),
        ref
            .read(playlistsOverviewProvider(_playlistsScope).notifier)
            .refresh(),
      ]);
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
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
    if (_isLoadingLatestMovies) {
      return _buildLatestMoviesSkeleton();
    }
    if (_latestMoviesErrorMessage != null) {
      return AppEmptyState(
        message: _latestMoviesErrorMessage!,
        onRetry: _loadLatestMovies,
      );
    }
    if (_latestMovies.isEmpty) {
      return const AppEmptyState(message: '暂无入库影片，去搜索看看吧');
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
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(playlistsOverviewProvider(_playlistsScope));
        final state = async.value;
        if (async.isLoading && state == null) {
          return _buildPlaylistsSkeleton();
        }
        if (async.hasError && state == null) {
          return AppEmptyState(
            message: apiErrorMessage(
              async.error!,
              fallback: '播放列表暂时无法加载，请稍后重试',
            ),
          );
        }
        final PlaylistsOverviewState effective =
            state ?? const PlaylistsOverviewState();
        if (effective.playlists.isEmpty) {
          return const AppEmptyState(message: '暂无播放列表');
        }

        final playlists = effective.playlists;
        if (playlists.length < 2) {
          final playlist = playlists.single;
          return Column(
            key: const Key('mobile-overview-playlists-list'),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: context.appSpacing.sm),
                child: PlaylistBannerCard(
                  key: Key('mobile-overview-playlist-${playlist.id}'),
                  title: playlist.name,
                  coverImageUrl: effective.coverUrlFor(playlist.id),
                  onTap:
                      () => MobilePlaylistDetailRouteData(
                        playlistId: playlist.id,
                      ).push(context),
                ),
              ),
            ],
          );
        }

        return ReorderableListView.builder(
          key: const Key('mobile-overview-playlists-list'),
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: playlists.length,
          onReorder: ref
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
                child: PlaylistBannerCard(
                  key: Key('mobile-overview-playlist-${playlist.id}'),
                  title: playlist.name,
                  coverImageUrl: effective.coverUrlFor(playlist.id),
                  onTap:
                      () => MobilePlaylistDetailRouteData(
                        playlistId: playlist.id,
                      ).push(context),
                ),
              ),
            );
          },
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
