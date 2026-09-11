import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_thumbnail_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';

class DesktopVideoThumbnailPage extends StatelessWidget {
  const DesktopVideoThumbnailPage({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('desktop-video-thumbnail-page-surface'),
      color: context.appColors.surfaceElevated,
      child: VideoThumbnailContent(
        videoId: videoId,
        thumbnailPreviewPresentation: MoviePlotPreviewPresentation.dialog,
        onSearchSimilar: (imageUrl, fileName) =>
            launchDesktopImageSearchFromUrl(
              context,
              imageUrl: imageUrl,
              fallbackPath: desktopVideosPath,
              fileName: fileName,
            ),
        onPlay: (offsetSeconds) async {
          context.pushDesktopVideoPlayer(
            videoId: videoId,
            fallbackPath: desktopVideosPath,
            positionSeconds: offsetSeconds,
          );
        },
      ),
    );
  }
}
