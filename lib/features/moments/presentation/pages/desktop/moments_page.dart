import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/pages/shared/moments_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';

/// 桌面时刻列表壳：导航四分支收在壳里（桌面图搜 launcher / 快播弹窗 /
/// push 桌面播放器与详情），Key 与滚动容器差异经 [MomentsContent] 参数透传。
class DesktopMomentsPage extends StatelessWidget {
  const DesktopMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MomentsContent(
      keyPrefix: 'moments',
      rootKey: const Key('moments-page'),
      onSearchSimilar: (context, item) => _searchSimilarFromMoment(
        context,
        item,
      ),
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
    await launchDesktopImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      fallbackPath: desktopMomentsPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
  }

  void _openVideoForMoment(BuildContext context, MomentListItem item) {
    unawaited(
      showVideoQuickPlayDialog(
        context,
        videoId: item.videoItemId!,
        title: item.displayLabel,
      ),
    );
  }

  void _openPlayerForMoment(BuildContext context, MomentListItem item) {
    context.pushDesktopMoviePlayer(
      movieNumber: item.movieNumber!,
      fallbackPath: desktopMomentsPath,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    );
  }

  void _openMovieDetailForMoment(BuildContext context, MomentListItem item) {
    context.pushDesktopMovieDetail(
      movieNumber: item.movieNumber!,
      fallbackPath: desktopMomentsPath,
    );
  }
}
