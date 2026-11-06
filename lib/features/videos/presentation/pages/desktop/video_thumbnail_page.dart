import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_thumbnail_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

class DesktopVideoThumbnailPage extends StatelessWidget {
  const DesktopVideoThumbnailPage({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context) {
    return VideoThumbnailContent(
      key: const Key('desktop-video-thumbnail-page-surface'),
      videoId: videoId,
      thumbnailPreviewPresentation: AppAdaptiveModalVariant.dialog,
      onSearchSimilar: (imageUrl, fileName) => launchDesktopImageSearchFromUrl(
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
    );
  }
}
