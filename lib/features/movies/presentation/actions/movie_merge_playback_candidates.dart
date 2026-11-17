import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
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
