import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_overlay_presenter.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_interaction_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

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

List<MovieMergePlaybackCandidateDto> resolveMovieMergePlaybackCandidates(
  MovieDetailDto movie, {
  required bool useExternalPlayer,
  required AppLocalizations l10n,
}) {
  if (useExternalPlayer) return movie.mergePlaybackCandidates;
  final libraryIds =
      movie.mediaItems
          .map((media) => media.libraryId)
          .whereType<int>()
          .toSet()
          .toList()
        ..sort();
  return [
    for (final libraryId in libraryIds)
      if (movieMergedPlaybackMedia(movie, libraryId) case final medias
          when medias.length >= 2)
        MovieMergePlaybackCandidateDto(
          libraryId: libraryId,
          libraryName:
              movie.mergePlaybackCandidates
                  .where((candidate) => candidate.libraryId == libraryId)
                  .firstOrNull
                  ?.libraryName ??
              l10n.movieWidgetMediaLibraryFallback(libraryId),
          providerKey: medias.first.providerKey ?? '',
          segmentCount: medias.length,
        ),
  ];
}

String? resolveMovieMergePlaybackLabel(
  List<MovieMergePlaybackCandidateDto> candidates,
  AppLocalizations l10n,
) {
  if (candidates.isEmpty) {
    return null;
  }
  if (candidates.length == 1) {
    return l10n.moviePageMergedPlaybackSegments(candidates.single.segmentCount);
  }
  return l10n.moviePageMergedPlayback;
}

Future<void> openMovieMergedPlayback({
  required BuildContext context,
  required WidgetRef ref,
  required String movieNumber,
  required MovieDetailDto movie,
  required List<MovieMergePlaybackCandidateDto> candidates,
  required bool mobile,
}) async {
  final provider = movieDetailInteractionProvider(movieNumber);
  if (ref.read(provider).isLaunchingPlayback) {
    return;
  }
  final candidate = await MovieDetailOverlayPresenter(
    mobile: mobile,
  ).pickMergeCandidate(context: context, candidates: candidates);
  if (candidate == null || !context.mounted) {
    return;
  }
  final notifier = ref.read(provider.notifier);
  notifier.setPlaybackLaunching(true);
  try {
    await launchMovieMergedPlayback(
      context,
      movieNumber: movie.movieNumber,
      libraryId: candidate.libraryId,
      movie: movie,
    );
  } finally {
    notifier.setPlaybackLaunching(false);
  }
}
