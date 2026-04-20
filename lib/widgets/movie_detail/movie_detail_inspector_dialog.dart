import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';

Future<void> showMovieDetailInspectorDialog({
  required BuildContext context,
  required String movieNumber,
  required MovieMediaItemDto? selectedMedia,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final moviesApi = dialogContext.read<MoviesApi>();
      final downloadsApi = dialogContext.read<DownloadsApi>();
      return AppDesktopDialog(
        dialogKey: const Key('movie-detail-inspector-dialog'),
        contentKey: const Key('movie-detail-inspector-dialog-content'),
        width: dialogContext.appComponentTokens.movieDetailDialogWidth,
        height: dialogContext.appComponentTokens.movieDetailDialogMinHeight,
        child: MovieDetailInspectorPanel(
          movieNumber: movieNumber,
          selectedMedia: selectedMedia,
          fetchMovieReviews: moviesApi.getMovieReviews,
          fetchMediaThumbnails: moviesApi.getMediaThumbnails,
          fetchMissavThumbnailsStream: moviesApi.getMissavThumbnailsStream,
          searchCandidates: downloadsApi.searchCandidates,
          createDownloadRequest: downloadsApi.createDownloadRequest,
          onClose: () => Navigator.of(dialogContext).pop(),
          showCloseButton: false,
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
                fallbackPath: buildDesktopMovieDetailRoutePath(movieNumber),
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
              context.pushDesktopMoviePlayer(
                movieNumber: movieNumber,
                fallbackPath: buildDesktopMovieDetailRoutePath(movieNumber),
                mediaId: thumbnail.mediaId > 0 ? thumbnail.mediaId : null,
                positionSeconds: thumbnail.offsetSeconds,
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
    builder: (sheetContext) {
      final moviesApi = sheetContext.read<MoviesApi>();
      final downloadsApi = sheetContext.read<DownloadsApi>();
      return MovieDetailInspectorPanel(
        movieNumber: movieNumber,
        selectedMedia: selectedMedia,
        fetchMovieReviews: moviesApi.getMovieReviews,
        fetchMediaThumbnails: moviesApi.getMediaThumbnails,
        fetchMissavThumbnailsStream: moviesApi.getMissavThumbnailsStream,
        searchCandidates: downloadsApi.searchCandidates,
        createDownloadRequest: downloadsApi.createDownloadRequest,
        onClose: () => Navigator.of(sheetContext).pop(),
        thumbnailPreviewPresentation: MoviePlotPreviewPresentation.bottomDrawer,
        onSearchSimilar: onSearchSimilar,
        onPlay: onPlay,
      );
    },
  );
}
