import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_controller.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/moments/moment_preview_dialog.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class MobileOverviewDiscoverTab extends StatefulWidget {
  const MobileOverviewDiscoverTab({super.key});

  @override
  State<MobileOverviewDiscoverTab> createState() =>
      _MobileOverviewDiscoverTabState();
}

class _MobileOverviewDiscoverTabState extends State<MobileOverviewDiscoverTab> {
  static const int _dailyPreviewCount = 6;
  static const int _momentPreviewCount = 4;

  late final DiscoveryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DiscoveryController(
      discoveryApi: context.read<DiscoveryApi>(),
      dailyPageSize: 10,
      momentPageSize: 10,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppAdaptiveRefreshScrollView(
          key: const Key('mobile-overview-discover-tab'),
          onRefresh: _handleRefresh,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: context.appSpacing.sm),
                  _buildDailySection(context),
                  SizedBox(height: context.appSpacing.lg),
                  _buildMomentSection(context),
                  SizedBox(height: context.appSpacing.lg),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Widget _buildDailySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '今日推荐',
          totalText: '${_controller.dailyTotal} 部',
          actionKey: const Key('mobile-discover-load-more-daily'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileDiscoverMoviesPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildDailyBody(context),
      ],
    );
  }

  Widget _buildDailyBody(BuildContext context) {
    if (_controller.dailyErrorMessage != null) {
      return _RetryEmptyState(
        message: _controller.dailyErrorMessage!,
        onRetry: _controller.refresh,
      );
    }
    return MovieSummaryGrid(
      items: _controller.dailyItems
          .take(_dailyPreviewCount)
          .map((item) => item.movie)
          .toList(growable: false),
      isLoading: _controller.isLoadingDaily,
      emptyMessage: '暂无每日推荐',
      placeholderCount: _dailyPreviewCount,
      onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
    );
  }

  Widget _buildMomentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '推荐时刻',
          totalText: '${_controller.momentTotal} 个',
          actionKey: const Key('mobile-discover-load-more-moments'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileDiscoverMomentsPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildMomentBody(context),
      ],
    );
  }

  Widget _buildMomentBody(BuildContext context) {
    if (_controller.isLoadingMoments) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.appLayoutTokens.emptySectionVerticalPadding,
          ),
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_controller.momentErrorMessage != null) {
      return _RetryEmptyState(
        message: _controller.momentErrorMessage!,
        onRetry: _controller.refresh,
      );
    }
    if (_controller.momentItems.isEmpty) {
      return const AppEmptyState(message: '暂无推荐时刻');
    }
    return MomentGrid(
      items: _controller.momentItems
          .take(_momentPreviewCount)
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: _openMomentPreview,
    );
  }

  void _openMovieDetail(String movieNumber) {
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
  }

  Future<void> _openMomentPreview(MomentListItem item) async {
    _MomentPreviewAction? selectedAction;
    final preview = MomentPreviewDialog(
      item: item,
      presentation: MediaPreviewPresentation.bottomDrawer,
      onSearchSimilar: () async {
        selectedAction = _MomentPreviewAction.searchSimilar;
        return true;
      },
      onPlay: () => selectedAction = _MomentPreviewAction.play,
      onOpenMovieDetail:
          () => selectedAction = _MomentPreviewAction.movieDetail,
    );

    await showAppBottomDrawer<void>(
      context: context,
      maxHeightFactor: 0.7,
      drawerKey: const Key('mobile-discover-moment-preview-bottom-sheet'),
      ignoreTopSafeArea: true,
      builder: (_) => preview,
    );

    if (!mounted || selectedAction == null) {
      return;
    }
    switch (selectedAction!) {
      case _MomentPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(item);
        break;
      case _MomentPreviewAction.play:
        MobileMoviePlayerRouteData(
          movieNumber: item.movieNumber,
          mediaId: item.mediaId > 0 ? item.mediaId : null,
          positionSeconds: item.offsetSeconds,
        ).push(context);
        break;
      case _MomentPreviewAction.movieDetail:
        MobileMovieDetailRouteData(movieNumber: item.movieNumber).push(context);
        break;
    }
  }

  Future<void> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return;
    }
    try {
      await launchImageSearchFromUrl(
        context,
        imageUrl: imageUrl,
        routePath: mobileImageSearchPath,
        fallbackPath: mobileOverviewPath,
        fileName: buildMomentImageFileName(item, imageUrl),
      );
    } catch (_) {
      if (mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
    }
  }
}

class _MobileDiscoverSectionTitle extends StatelessWidget {
  const _MobileDiscoverSectionTitle({
    required this.title,
    required this.totalText,
    required this.actionKey,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String totalText;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          totalText,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        const Spacer(),
        AppTextButton(
          key: actionKey,
          label: actionLabel,
          size: AppTextButtonSize.xSmall,
          trailingIcon: const Icon(Icons.chevron_right_rounded),
          onPressed: onActionTap,
        ),
      ],
    );
  }
}

class _RetryEmptyState extends StatelessWidget {
  const _RetryEmptyState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          key: Key('mobile-discover-retry-${message.hashCode}'),
          label: '重试',
          size: AppButtonSize.small,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}

enum _MomentPreviewAction { searchSimilar, play, movieDetail }
