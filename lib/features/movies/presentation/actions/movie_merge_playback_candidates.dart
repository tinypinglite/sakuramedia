import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_merge_playback_selector.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

List<MovieMediaItemDto> movieMergedPlaybackMedia(
  MovieDetailDto movie,
  int libraryId,
) =>
    movie.mediaItems
        .where(
          (media) =>
              media.libraryId == libraryId &&
              media.valid &&
              media.hasPlayableUrl,
        )
        .toList()
      ..sort((a, b) => a.mediaId.compareTo(b.mediaId));

List<int> movieMergePlaybackLibraryIds(
  MovieDetailDto movie, {
  Set<int>? supportedLibraryIds,
}) {
  final libraryIds =
      movie.mediaItems
          .map((media) => media.libraryId)
          .whereType<int>()
          .toSet()
          .toList()
        ..sort();
  return [
    for (final libraryId in libraryIds)
      if ((supportedLibraryIds == null ||
              supportedLibraryIds.contains(libraryId)) &&
          movieMergedPlaybackMedia(movie, libraryId).length >= 2)
        libraryId,
  ];
}

bool hasMovieMergePlaybackCandidate(
  MovieDetailDto movie, {
  Set<int>? supportedExternalLibraryIds,
}) {
  return movieMergePlaybackLibraryIds(
    movie,
    supportedLibraryIds: supportedExternalLibraryIds,
  ).isNotEmpty;
}

Future<void> openMovieMergedPlayback({
  required BuildContext context,
  required String movieNumber,
  required MovieDetailDto movie,
  required bool mobile,
}) async {
  final l10n = AppLocalizations.of(context);
  final externalSelection = await readExternalPlayerSelection(context);
  if (!context.mounted) {
    return;
  }
  final externalAvailable =
      externalSelection != null && isExternalPlayerAvailable(externalSelection);
  final supportedExternalLibraryIds = externalAvailable
      ? movie.mergePlaybackCandidates
            .map((candidate) => candidate.libraryId)
            .toSet()
      : null;
  if (supportedExternalLibraryIds != null &&
      supportedExternalLibraryIds.isEmpty) {
    showToast(
      l10n.movieActionMergedPlaybackUnavailable,
      tone: AppToastTone.error,
    );
    return;
  }
  final playerLabel =
      (externalSelection?.label ?? externalSelection?.playerId ?? '').trim();
  final modeDescription = externalAvailable
      ? l10n.movieMergePlaybackExternalMode(
          playerLabel.isEmpty ? l10n.configTabExternalPlayer : playerLabel,
        )
      : l10n.movieMergePlaybackInAppMode;

  final submission = await showMovieMergePlaybackSelector(
    context: context,
    movie: movie,
    modeDescription: modeDescription,
    mobile: mobile,
    externalMergeSupportedLibraryIds: supportedExternalLibraryIds,
    onSubmit: (selection) => prepareMovieMergedPlayback(
      context,
      movieNumber: movieNumber,
      movie: movie,
      selection: selection,
      externalSelection: externalAvailable ? externalSelection : null,
    ),
  );
  if (submission == null || !context.mounted) {
    return;
  }
  await launchPreparedMovieMergedPlayback(
    context,
    submission,
    movieNumber: movieNumber,
  );
}
