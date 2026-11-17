import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

class MovieDetailApplyResult {
  const MovieDetailApplyResult({
    required this.selectedMediaId,
    this.isSubscribedOverride,
    this.isCollectionOverride,
  });

  final int? selectedMediaId;
  final bool? isSubscribedOverride;
  final bool? isCollectionOverride;
}

/// 详情页取跨页订阅广播的入口——批 8 起 `movieSubscriptionEventsProvider` 是
/// keepAlive 常驻的 Riverpod class Notifier，直接由容器读出。
MovieSubscriptionEvents resolveMovieSubscriptionNotifier(BuildContext context) {
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(movieSubscriptionEventsProvider.notifier);
}

MovieDetailApplyResult applyReturnedMovieDetail({
  required WidgetRef ref,
  required String movieNumber,
  required MovieDetailDto movie,
  required int? selectedMediaId,
  required bool resetPreview,
}) {
  final resolvedSelectedMediaId =
      selectedMediaId != null &&
          movie.mediaItems.any((item) => item.mediaId == selectedMediaId)
      ? selectedMediaId
      : (movie.mediaItems.isNotEmpty ? movie.mediaItems.first.mediaId : null);
  ref
      .read(movieDetailProvider(movieNumber).notifier)
      .applyMovie(movie, resetPreview: resetPreview);
  return MovieDetailApplyResult(
    selectedMediaId: resolvedSelectedMediaId,
    isSubscribedOverride: null,
    isCollectionOverride: null,
  );
}
