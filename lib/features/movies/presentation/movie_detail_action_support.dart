import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';

class MovieDetailRemoteActionSpec {
  const MovieDetailRemoteActionSpec({
    required this.request,
    required this.successMessage,
    required this.failureMessage,
    this.resetPreview = false,
  });

  final Future<MovieDetailDto> Function(MoviesApi api) request;
  final String successMessage;
  final String failureMessage;
  final bool resetPreview;
}

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

class MovieSubscriptionNotifierBinding {
  const MovieSubscriptionNotifierBinding({
    required this.notifier,
    required this.ownsNotifier,
  });

  final MovieSubscriptionChangeNotifier notifier;
  final bool ownsNotifier;
}

MovieSubscriptionNotifierBinding resolveMovieSubscriptionNotifier(
  BuildContext context,
) {
  try {
    return MovieSubscriptionNotifierBinding(
      notifier: context.read<MovieSubscriptionChangeNotifier>(),
      ownsNotifier: false,
    );
  } on ProviderNotFoundException {
    return MovieSubscriptionNotifierBinding(
      notifier: MovieSubscriptionChangeNotifier(),
      ownsNotifier: true,
    );
  }
}

MovieDetailRemoteActionSpec? movieDetailRemoteActionSpecFor({
  required MovieDetailActionType action,
  required String movieNumber,
}) {
  switch (action) {
    case MovieDetailActionType.toggleSubscription:
      return null;
    case MovieDetailActionType.refreshMetadata:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.refreshMovieMetadata(movieNumber: movieNumber),
        successMessage: '影片元数据已刷新',
        failureMessage: '刷新影片元数据失败',
        resetPreview: true,
      );
    case MovieDetailActionType.recomputeHeat:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.recomputeMovieHeat(movieNumber: movieNumber),
        successMessage: '影片热度已更新',
        failureMessage: '计算影片热度失败',
      );
    case MovieDetailActionType.syncInteraction:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.syncMovieInteraction(movieNumber: movieNumber),
        successMessage: '影片互动数已同步',
        failureMessage: '刷新影片互动数失败',
      );
    case MovieDetailActionType.translateDescription:
      return MovieDetailRemoteActionSpec(
        request:
            (api) => api.translateMovieDescription(movieNumber: movieNumber),
        successMessage: '影片介绍已翻译',
        failureMessage: '翻译影片介绍失败',
      );
  }
}

Future<bool> executeMovieDetailRemoteAction({
  required BuildContext context,
  required MovieDetailActionType action,
  required String movieNumber,
  required bool isLocked,
  required MovieDetailController controller,
  required int? selectedMediaId,
  required void Function(MovieDetailActionType? action) onActiveActionChanged,
  required void Function(MovieDetailApplyResult result) onMovieApplied,
}) async {
  final spec = movieDetailRemoteActionSpecFor(
    action: action,
    movieNumber: movieNumber,
  );
  if (spec == null || isLocked) {
    return false;
  }

  onActiveActionChanged(action);
  try {
    final movie = await spec.request(context.read<MoviesApi>());
    if (!context.mounted) {
      return false;
    }
    final applyResult = applyReturnedMovieDetail(
      controller: controller,
      movie: movie,
      selectedMediaId: selectedMediaId,
      resetPreview: spec.resetPreview,
    );
    onMovieApplied(applyResult);
    showToast(spec.successMessage);
    return true;
  } catch (error) {
    if (context.mounted) {
      showToast(apiErrorMessage(error, fallback: spec.failureMessage));
    }
    return false;
  } finally {
    onActiveActionChanged(null);
  }
}

MovieDetailApplyResult applyReturnedMovieDetail({
  required MovieDetailController controller,
  required MovieDetailDto movie,
  required int? selectedMediaId,
  required bool resetPreview,
}) {
  final resolvedSelectedMediaId =
      selectedMediaId != null &&
              movie.mediaItems.any((item) => item.mediaId == selectedMediaId)
          ? selectedMediaId
          : (movie.mediaItems.isNotEmpty
              ? movie.mediaItems.first.mediaId
              : null);
  controller.applyMovie(movie, resetPreview: resetPreview);
  return MovieDetailApplyResult(
    selectedMediaId: resolvedSelectedMediaId,
    isSubscribedOverride: null,
    isCollectionOverride: null,
  );
}
