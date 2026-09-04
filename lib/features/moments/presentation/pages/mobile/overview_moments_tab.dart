import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/pages/shared/moments_content.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';

/// 移动概览「时刻」tab 壳：导航四分支收在壳里（draft store 中转图搜 /
/// push 全屏视频页 / launchMoviePlayback / push 移动详情），下拉刷新与底部抽屉
/// 筛选、预览弹层 Key 经 [MomentsContent] 参数透传。
class MobileOverviewMomentsTab extends StatelessWidget {
  const MobileOverviewMomentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return MomentsContent(
      keyPrefix: 'mobile-moments',
      rootKey: const Key('mobile-overview-moments-tab'),
      previewDrawerKey: const Key('mobile-moments-preview-bottom-sheet'),
      enablePullToRefresh: true,
      useMobileFilterDrawer: true,
      onSearchSimilar: _searchSimilarFromMoment,
      onOpenVideo: _openVideoForMoment,
      onOpenPlayer: _openPlayerForMoment,
      onOpenMovieDetail: _openMovieDetailForMoment,
    );
  }

  Future<void> _searchSimilarFromMoment(
    BuildContext context,
    MomentListItem item,
  ) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return;
    }
    await launchImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      routePath: mobileImageSearchPath,
      fallbackPath: mobileOverviewPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
  }

  Future<void> _openVideoForMoment(
    BuildContext context,
    MomentListItem item,
  ) async {
    if (await tryLaunchExternalVideoPlayback(
      context,
      videoId: item.videoItemId!,
      title: item.displayLabel,
    )) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileVideoPlayerPage(
          videoId: item.videoItemId!,
          title: item.displayLabel,
        ),
      ),
    );
  }

  void _openPlayerForMoment(BuildContext context, MomentListItem item) {
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: item.movieNumber!,
        mediaId: item.mediaId > 0 ? item.mediaId : null,
        positionSeconds: item.offsetSeconds,
      ),
    );
  }

  void _openMovieDetailForMoment(BuildContext context, MomentListItem item) {
    MobileMovieDetailRouteData(movieNumber: item.movieNumber!).push(context);
  }
}
