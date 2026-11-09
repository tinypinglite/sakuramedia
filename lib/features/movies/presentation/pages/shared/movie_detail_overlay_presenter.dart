import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_tag_assignment_editor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_copy.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_plot_image_actions.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_merge_playback_candidate_list.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_subtitle_viewer.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/movie_playlist_picker_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_mobile_confirm_actions.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

const Key _movieMediaDeleteDialogKey = Key('movie-media-delete-confirm-dialog');
const Key _movieMediaDeleteDrawerKey = Key('movie-media-delete-confirm-drawer');

class MovieDetailOverlayPresenter {
  const MovieDetailOverlayPresenter({required this.mobile});

  final bool mobile;

  Future<MovieDetailActionType?> showActionMenu({
    required BuildContext context,
    required Offset globalPosition,
    required MovieDetailDto movie,
    required bool isSubscribed,
    required bool isCollection,
    required bool isBlacklisted,
    required MovieMediaItemDto? selectedMedia,
    required String? castSessionLabel,
    required bool canCast,
  }) {
    final actions = buildMovieDetailActionDescriptors(
      l10n: AppLocalizations.of(context),
      isSubscribed: isSubscribed,
      isCollection: isCollection,
      isBlacklisted: isBlacklisted,
      canCast: canCast,
      castSessionLabel: castSessionLabel,
    );
    return mobile
        ? showMovieDetailMobileActionDrawer(context: context, actions: actions)
        : showMovieDetailDesktopActionMenu(
            context: context,
            globalPosition: globalPosition,
            actions: actions,
          );
  }

  Future<bool?> confirmDeleteMedia({
    required BuildContext context,
    required MovieMediaItemDto mediaItem,
  }) {
    final l10n = AppLocalizations.of(context);
    if (!mobile) {
      return showAppConfirmDialog(
        context,
        title: l10n.moviePageMediaDeleteTitle,
        message: _mediaDeleteMessage(context, mediaItem),
        confirmLabel: l10n.commonDelete,
        danger: true,
        dialogKey: _movieMediaDeleteDialogKey,
        confirmKey: const Key('movie-media-delete-confirm'),
        cancelKey: const Key('movie-media-delete-cancel'),
        extraContent: Text(
          _mediaDeleteLabel(context, mediaItem),
          key: const Key('movie-media-delete-path'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      );
    }
    return showAppBottomDrawer<bool>(
      context: context,
      drawerKey: _movieMediaDeleteDrawerKey,
      maxHeightFactor: 0.48,
      builder: (drawerContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.moviePageMediaDeleteTitle,
            style: resolveAppTextStyle(drawerContext, size: AppTextSize.s18),
          ),
          SizedBox(height: drawerContext.appSpacing.lg),
          Text(_mediaDeleteMessage(drawerContext, mediaItem)),
          SizedBox(height: drawerContext.appSpacing.sm),
          Text(
            _mediaDeleteLabel(drawerContext, mediaItem),
            key: const Key('movie-media-delete-path'),
            style: resolveAppTextStyle(
              drawerContext,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: drawerContext.appSpacing.xl),
          AppMobileConfirmActions(
            cancelKey: const Key('movie-media-delete-cancel'),
            confirmKey: const Key('movie-media-delete-confirm'),
            confirmLabel: l10n.commonDelete,
            isDangerous: true,
            onCancel: () => Navigator.of(drawerContext).pop(false),
            onConfirm: () => Navigator.of(drawerContext).pop(true),
          ),
        ],
      ),
    );
  }

  Future<bool> confirmBlacklist(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAppConfirmDialog(
      context,
      title: l10n.moviePageBlacklistTitle,
      message: l10n.moviePageBlacklistWarning,
      confirmLabel: l10n.moviePageBlacklistConfirm,
      danger: true,
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
    );
  }

  Future<bool> confirmRefreshMetadata({
    required BuildContext context,
    required bool isActorsManuallyManaged,
  }) {
    final l10n = AppLocalizations.of(context);
    return showAppConfirmDialog(
      context,
      title: MovieDetailRefreshConfirmationCopy.title(l10n),
      message: MovieDetailRefreshConfirmationCopy.descriptionFor(
        l10n,
        isActorsManuallyManaged: isActorsManuallyManaged,
      ),
      extraContent: Text(
        MovieDetailRefreshConfirmationCopy.hint(l10n),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        ),
      ),
      confirmLabel: MovieDetailRefreshConfirmationCopy.confirmLabel(l10n),
      cancelLabel: MovieDetailRefreshConfirmationCopy.cancelLabel(l10n),
      dialogKey: const Key('movie-detail-refresh-metadata-dialog'),
      confirmKey: const Key('movie-detail-refresh-metadata-confirm'),
      cancelKey: const Key('movie-detail-refresh-metadata-cancel'),
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
    );
  }

  Future<void> openInspector({
    required BuildContext context,
    required MovieDetailDto movie,
    required MovieMediaItemDto? selectedMedia,
    required MovieDetailInspectorPane pane,
    required Future<void> Function(
      MovieMediaThumbnailDto thumbnail,
      String imageUrl,
      String fileName,
    )
    onSearchSimilar,
    required void Function(MovieMediaThumbnailDto thumbnail) onPlay,
  }) {
    if (mobile) {
      return showMobileMovieDetailInspectorBottomSheet(
        context: context,
        movieNumber: movie.movieNumber,
        movieTitle: movie.title,
        movieCoverUrl: movie.preferredCoverUrl,
        selectedMedia: selectedMedia,
        pane: pane,
        onSearchSimilar: (thumbnail, imageUrl, fileName) =>
            onSearchSimilar(thumbnail, imageUrl, fileName),
        onPlay: (thumbnail) => onPlay(thumbnail),
      );
    }
    return showMovieDetailInspectorDialog(
      context: context,
      movieNumber: movie.movieNumber,
      movieTitle: movie.title,
      movieCoverUrl: movie.preferredCoverUrl,
      selectedMedia: selectedMedia,
      pane: pane,
    );
  }

  Future<MediaPreviewAction?> openMediaPointPreview({
    required BuildContext context,
    required MediaPreviewItem item,
    required Set<MediaPreviewAction> availableActions,
    required VoidCallback onPointRemoved,
  }) {
    return showMediaPreviewOverlay(
      context: context,
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      drawerKey: mobile
          ? const Key('movie-media-point-preview-bottom-sheet')
          : null,
      builder: (_) => MediaPreviewDialog(
        item: item,
        availableActions: availableActions,
        onPointRemoved: onPointRemoved,
        closeOnPointRemoved: true,
      ),
    );
  }

  Future<MediaTagAssignmentDto?> editMediaTags({
    required BuildContext context,
    required MovieMediaItemDto mediaItem,
  }) {
    return showMediaTagAssignmentEditor(
      context,
      mediaId: mediaItem.mediaId,
      mobile: mobile,
    );
  }

  Future<void> showPlaylistPicker({
    required BuildContext context,
    required MovieDetailDto movie,
  }) {
    return showMoviePlaylistPickerDialog(
      context,
      movieNumber: movie.movieNumber,
      initialPlaylists: movie.playlists,
      presentation: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
    );
  }

  Future<void> showPlotPreview({
    required BuildContext context,
    required MovieDetailDto movie,
    required int initialIndex,
    required Future<void> Function(
      BuildContext menuContext,
      int index,
      Offset globalPosition,
    )
    onRequestImageMenu,
  }) {
    return showMoviePlotPreviewOverlay(
      context: context,
      plotImages: movie.plotImages,
      initialIndex: initialIndex,
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      onRequestImageMenu: onRequestImageMenu,
    );
  }

  Future<void> showPlotImageMenu({
    required BuildContext context,
    required BuildContext hostContext,
    required MovieDetailDto movie,
    required int index,
    required Offset globalPosition,
    required bool closeCurrentRouteOnSearch,
    Future<void> Function(
      BuildContext context,
      String imageUrl,
      String fileName,
    )?
    onSearchSimilar,
  }) {
    return showMoviePlotImageActionMenu(
      context: context,
      hostContext: hostContext,
      plotImages: movie.plotImages,
      movieNumber: movie.movieNumber,
      index: index,
      globalPosition: globalPosition,
      closeCurrentRouteOnSearch: closeCurrentRouteOnSearch,
      onSearchSimilar: mobile ? onSearchSimilar : null,
    );
  }

  Future<void> openSubtitle({
    required BuildContext context,
    required MovieSubtitleItemDto item,
  }) {
    return showMovieSubtitleViewer(context, item: item);
  }

  Future<MovieMergePlaybackCandidateDto?> pickMergeCandidate({
    required BuildContext context,
    required List<MovieMergePlaybackCandidateDto> candidates,
  }) {
    if (candidates.length == 1) {
      return Future<MovieMergePlaybackCandidateDto?>.value(candidates.single);
    }
    return showAppAdaptiveModal<MovieMergePlaybackCandidateDto>(
      context: context,
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      dialogKey: const Key('movie-merge-playback-library-dialog'),
      drawerKey: const Key('movie-merge-playback-library-drawer'),
      desktopWidth: context.appLayoutTokens.dialogWidthSm,
      mobileMaxHeightFactor: 0.5,
      builder: (modalContext) => MovieMergePlaybackCandidateList(
        candidates: candidates,
        onSelected: (candidate) => Navigator.of(modalContext).pop(candidate),
      ),
    );
  }

  Future<MovieDetailActionResult> searchSimilarFromPoint({
    required BuildContext context,
    required WidgetRef ref,
    required String movieNumber,
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      if (mobile) {
        await _openMobileImageSearch(
          context: context,
          ref: ref,
          movieNumber: movieNumber,
          imageUrl: imageUrl,
          fileName: fileName,
        );
      } else {
        await launchDesktopImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          fallbackPath: DesktopRoutes.movieDetail(
            movieNumber: movieNumber,
          ).location,
          fileName: fileName,
          currentMovieNumber: movieNumber,
        );
      }
      return const MovieDetailActionResult.success();
    } catch (error) {
      if (!context.mounted) {
        return const MovieDetailActionResult.ignored();
      }
      final l10n = AppLocalizations.of(context);
      return MovieDetailActionResult.error(
        apiErrorMessage(
          error,
          fallback: l10n.moviePageImageLoadFailed,
          l10n: l10n,
        ),
      );
    }
  }

  Future<void> _openMobileImageSearch({
    required BuildContext context,
    required WidgetRef ref,
    required String movieNumber,
    required String imageUrl,
    required String fileName,
  }) async {
    final imageBytes = await ref.read(apiClientProvider).getBytes(imageUrl);
    if (!context.mounted) return;
    final draftId = ref
        .read(imageSearchDraftStoreProvider)
        .save(
          fileName: fileName,
          bytes: imageBytes,
          mimeType: guessImageMimeType(fileName),
        );
    MobileRoutes.imageSearch(
      draftId: draftId,
      currentMovieNumber: movieNumber,
    ).push(context);
  }

  String _mediaDeleteLabel(BuildContext context, MovieMediaItemDto mediaItem) {
    final fileName = mediaItem.fileName.trim();
    if (fileName.isNotEmpty) {
      return fileName;
    }
    return AppLocalizations.of(context).moviePageMediaLabel(mediaItem.mediaId);
  }

  String _mediaDeleteMessage(
    BuildContext context,
    MovieMediaItemDto mediaItem,
  ) {
    final l10n = AppLocalizations.of(context);
    final fileName = mediaItem.fileName.trim();
    final label = fileName.isNotEmpty
        ? fileName
        : l10n.moviePageMediaSourceLabel(mediaItem.mediaId);
    final prefix = l10n.moviePageMediaDeleteConfirm(label);
    return '$prefix ${l10n.moviePageMediaDeleteWarning}';
  }
}
