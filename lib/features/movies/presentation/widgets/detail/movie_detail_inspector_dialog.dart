import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<void> showMovieDetailInspectorDialog({
  required BuildContext context,
  required String movieNumber,
  required MovieMediaItemDto? selectedMedia,
  required MovieDetailInspectorPane pane,
  String? movieTitle,
  String? movieCoverUrl,
}) {
  return showAppDialog<void>(
    context: context,
    // 挂在 shell navigator 上，搜索页才能 push 到弹窗之上；弹窗在搜索期间
    // 保持 mounted，返回时评论列表的滚动位置和分页状态都原样保留。
    useRootNavigator: false,
    builder: (dialogContext) {
      return AppDesktopDialog(
        dialogKey: const Key('movie-detail-inspector-dialog'),
        contentKey: const Key('movie-detail-inspector-dialog-content'),
        width: dialogContext.appComponentTokens.movieDetailDialogWidth,
        height: dialogContext.appComponentTokens.movieDetailDialogMinHeight,
        child: MovieDetailInspectorPanel(
          movieNumber: movieNumber,
          movieTitle: movieTitle,
          movieCoverUrl: movieCoverUrl,
          selectedMedia: selectedMedia,
          pane: pane,
          onSearchSelection: (query) => DesktopRoutes.search(
            query: query,
            fallbackPath: DesktopRoutes.movieDetail(
              movieNumber: movieNumber,
            ).location,
          ).push(dialogContext),
          onSearchSimilar: (thumbnail, imageUrl, fileName) async {
            if (!context.mounted || !dialogContext.mounted) {
              return;
            }
            final navigator = Navigator.of(dialogContext);
            if (navigator.canPop()) {
              navigator.pop();
            }
            Future<void>.microtask(() async {
              if (!context.mounted) {
                return;
              }
              await launchDesktopImageSearchFromUrl(
                context,
                imageUrl: imageUrl,
                fallbackPath: DesktopRoutes.movieDetail(
                  movieNumber: movieNumber,
                ).location,
                fileName: fileName,
              );
            });
          },
          onPlay: (thumbnail) {
            if (!context.mounted || !dialogContext.mounted) {
              return;
            }
            final navigator = Navigator.of(dialogContext);
            if (navigator.canPop()) {
              navigator.pop();
            }
            Future<void>.microtask(() {
              if (!context.mounted) {
                return;
              }
              unawaited(
                launchMoviePlayback(
                  context,
                  movieNumber: movieNumber,
                  mediaId: thumbnail.mediaId > 0 ? thumbnail.mediaId : null,
                  positionSeconds: thumbnail.offsetSeconds,
                ),
              );
            });
          },
        ),
      );
    },
  );
}

Future<void> showMobileMovieDetailInspectorBottomSheet({
  required BuildContext context,
  required String movieNumber,
  required MovieMediaItemDto? selectedMedia,
  required MovieDetailInspectorPane pane,
  String? movieTitle,
  String? movieCoverUrl,
  required Future<void> Function(
    MovieMediaThumbnailDto thumbnail,
    String imageUrl,
    String fileName,
  )
  onSearchSimilar,
  required void Function(MovieMediaThumbnailDto thumbnail) onPlay,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('movie-detail-inspector-bottom-sheet'),
    maxHeightFactor: 0.7,
    ignoreTopSafeArea: true,
    builder: (_) {
      return MovieDetailInspectorPanel(
        movieNumber: movieNumber,
        movieTitle: movieTitle,
        movieCoverUrl: movieCoverUrl,
        selectedMedia: selectedMedia,
        pane: pane,
        thumbnailPreviewPresentation: AppAdaptiveModalVariant.drawer,
        onSearchSimilar: onSearchSimilar,
        onPlay: onPlay,
        onSearchSelection: (query) =>
            MobileRoutes.search(query: query).push(context),
      );
    },
  );
}
