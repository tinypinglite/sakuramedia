import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_thumbnail_content.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';

class MobileVideoThumbnailPage extends StatelessWidget {
  const MobileVideoThumbnailPage({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('mobile-video-thumbnail-page-surface'),
      color: context.appColors.surfaceCard,
      child: VideoThumbnailContent(
        videoId: videoId,
        thumbnailPreviewPresentation: MoviePlotPreviewPresentation.bottomDrawer,
        onSearchSimilar: (imageUrl, fileName) => launchImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          routePath: mobileImageSearchPath,
          fallbackPath: mobilePornboxPath,
          fileName: fileName,
        ),
        onPlay: (offsetSeconds) => MobileVideoPlayerRouteData(
          videoId: videoId,
          positionSeconds: offsetSeconds,
        ).push<void>(context),
      ),
    );
  }
}
