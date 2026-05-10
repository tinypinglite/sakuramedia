import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_controller.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/moments/moment_preview_dialog.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class DesktopDiscoverPage extends StatefulWidget {
  const DesktopDiscoverPage({super.key});

  @override
  State<DesktopDiscoverPage> createState() => _DesktopDiscoverPageState();
}

class _DesktopDiscoverPageState extends State<DesktopDiscoverPage> {
  late final DiscoveryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DiscoveryController(
      discoveryApi: context.read<DiscoveryApi>(),
      dailyPageSize: 6,
      momentPageSize: 8,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AppPageFrame(
        title: '',
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              key: const Key('desktop-discover-page'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDailySection(context),
                SizedBox(height: context.appSpacing.xl),
                _buildMomentSection(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiscoverSectionTitle(
          title: '今日推荐',
          totalText: '${_controller.dailyTotal} 部',
          actionKey: const Key('desktop-discover-load-more-daily'),
          actionLabel: '更多',
          onActionTap: () => context.push(desktopDiscoverMoviesPath),
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
          .map((item) => item.movie)
          .toList(growable: false),
      isLoading: _controller.isLoadingDaily,
      emptyMessage: '暂无每日推荐',
      placeholderCount: 6,
      onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
    );
  }

  Widget _buildMomentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiscoverSectionTitle(
          title: '推荐时刻',
          totalText: '${_controller.momentTotal} 个',
          actionKey: const Key('desktop-discover-load-more-moments'),
          actionLabel: '更多',
          onActionTap: () => context.push(desktopDiscoverMomentsPath),
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
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: _openMomentPreview,
    );
  }

  void _openMovieDetail(String movieNumber) {
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopDiscoverPath,
    );
  }

  Future<void> _openMomentPreview(MomentListItem item) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => MomentPreviewDialog(
            item: item,
            onSearchSimilar: () => _searchSimilarFromMoment(item),
            onPlay: () => _openPlayerForMoment(item),
            onOpenMovieDetail: () => _openMovieDetailForMoment(item),
          ),
    );
  }

  Future<bool> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return false;
    }
    await launchDesktopImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      fallbackPath: desktopDiscoverPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
    return true;
  }

  void _openPlayerForMoment(MomentListItem item) {
    context.pushDesktopMoviePlayer(
      movieNumber: item.movieNumber,
      fallbackPath: desktopDiscoverPath,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    );
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    context.pushDesktopMovieDetail(
      movieNumber: item.movieNumber,
      fallbackPath: desktopDiscoverPath,
    );
  }
}

class _DiscoverSectionTitle extends StatelessWidget {
  const _DiscoverSectionTitle({
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
            size: AppTextSize.s18,
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
          size: AppTextButtonSize.small,
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
          key: Key('desktop-discover-retry-${message.hashCode}'),
          label: '重试',
          size: AppButtonSize.small,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}
