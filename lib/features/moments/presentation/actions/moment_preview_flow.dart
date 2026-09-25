import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_to_moment_collection_dialog.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';

/// 时刻预览统一流程：全部时刻列表与时刻合集详情都走这里。
///
/// 预览层固定按「内联导航 + 可加入合集 + 演员可点」配置，关闭后由本函数统一
/// 分发相似图片 / 加入合集 / 播放 / 影片详情 / 演员详情，避免各入口各写一套
/// 回执处理导致同一弹层行为不一致。平台分支与预览形态一致，读
/// `AppPlatformScope`（查不到按桌面）。发现推荐时刻有自己的动作集，不走这里。
Future<void> showMomentPreviewFlow({
  required BuildContext context,
  required MomentListItem item,
  required String fallbackPath,
  Key? drawerKey,
  required VoidCallback onPointRemoved,
}) async {
  int? selectedActorId;
  final action = await showMomentPreviewOverlay(
    context: context,
    item: item,
    pointId: item.pointId,
    presentation: MediaPreviewPresentation.auto,
    drawerKey: drawerKey,
    onPointRemoved: onPointRemoved,
    closeOnPointRemoved: true,
    allowAddToCollection: true,
    useInlineNavigation: true,
    onActorSelected: (actorId) => selectedActorId = actorId,
  );
  if (!context.mounted) {
    return;
  }
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  final actorId = selectedActorId;
  if (actorId != null) {
    isMobile
        ? MobileActorDetailRouteData(actorId: actorId).push(context)
        : context.pushDesktopActorDetail(
            actorId: actorId,
            fallbackPath: fallbackPath,
          );
    return;
  }
  switch (action) {
    case MediaPreviewAction.searchSimilar:
      await _searchSimilar(context, item, isMobile, fallbackPath);
    case MediaPreviewAction.addToCollection:
      await showAddToMomentCollectionDialog(context, pointId: item.pointId);
    case MediaPreviewAction.play:
      await playMomentItem(
        context: context,
        item: item,
        fallbackPath: fallbackPath,
      );
    case MediaPreviewAction.openMovieDetail:
      openMomentSourceMovie(
        context: context,
        item: item,
        fallbackPath: fallbackPath,
      );
    case null:
      return;
  }
}

/// 打开时刻来源影片详情：预览回执、时刻列表与合集详情的悬停「影片」都走这里。
///
/// 视频时刻没有影片详情（`movieNumber` 为空），直接忽略；平台按
/// `AppPlatformScope` 自行判定（查不到按桌面）。
void openMomentSourceMovie({
  required BuildContext context,
  required MomentListItem item,
  required String fallbackPath,
}) {
  if (item.isVideo) {
    return;
  }
  final movieNumber = item.movieNumber;
  if (movieNumber == null || movieNumber.isEmpty) {
    return;
  }
  if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
    return;
  }
  context.pushDesktopMovieDetail(
    movieNumber: movieNumber,
    fallbackPath: fallbackPath,
  );
}

Future<void> _searchSimilar(
  BuildContext context,
  MomentListItem item,
  bool isMobile,
  String fallbackPath,
) async {
  final imageUrl = resolveMomentImageUrl(item);
  if (imageUrl.isEmpty) {
    return;
  }
  try {
    await launchImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      routePath: isMobile ? mobileImageSearchPath : desktopImageSearchPath,
      fallbackPath: fallbackPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
  } catch (_) {
    if (context.mounted) {
      showToast('读取结果图片失败，请稍后重试');
    }
  }
}

/// 播放一个时刻：JAV 时刻跳进影片播放器的对应位置，视频时刻走快速播放。
///
/// 预览回执与时刻列表悬停播放键共用；平台按 `AppPlatformScope` 自行判定
/// （查不到按桌面），保证两个入口行为一致。
Future<void> playMomentItem({
  required BuildContext context,
  required MomentListItem item,
  required String fallbackPath,
}) async {
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  if (!item.isVideo) {
    final movieNumber = item.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return;
    }
    await launchMoviePlayback(
      context,
      movieNumber: movieNumber,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
      inAppFallbackPath: fallbackPath,
    );
    return;
  }
  final videoId = item.videoItemId;
  if (videoId == null || videoId <= 0) {
    return;
  }
  if (!isMobile) {
    await showVideoQuickPlayDialog(
      context,
      videoId: videoId,
      title: item.displayLabel,
    );
    return;
  }
  if (await tryLaunchExternalVideoPlayback(
    context,
    videoId: videoId,
    title: item.displayLabel,
  )) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          MobileVideoPlayerPage(videoId: videoId, title: item.displayLabel),
    ),
  );
}
