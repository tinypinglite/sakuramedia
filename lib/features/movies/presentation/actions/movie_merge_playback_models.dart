import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';

class MovieMergePlaybackSelection {
  const MovieMergePlaybackSelection({required this.mediaItems});

  final List<MovieMediaItemDto> mediaItems;

  int get libraryId => mediaItems.first.libraryId!;

  List<int> get mediaIds =>
      mediaItems.map((media) => media.mediaId).toList(growable: false);
}

class MovieMergePlaybackSubmission {
  const MovieMergePlaybackSubmission.inApp({required this.selection})
    : externalUrl = null,
      playerId = null,
      title = null;

  const MovieMergePlaybackSubmission.external({
    required this.selection,
    required this.externalUrl,
    required this.playerId,
    required this.title,
  });

  final MovieMergePlaybackSelection selection;
  final String? externalUrl;
  final String? playerId;
  final String? title;

  bool get usesExternalPlayer => externalUrl != null;
}

class MovieMergePlaybackSubmitException implements Exception {
  const MovieMergePlaybackSubmitException(this.message);

  final String message;
}
