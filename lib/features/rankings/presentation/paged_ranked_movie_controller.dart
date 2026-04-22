import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

typedef RankedMoviePageFetcher =
    Future<PaginatedResponseDto<RankedMovieListItemDto>> Function(
      int page,
      int pageSize,
    );

class PagedRankedMovieController
    extends PagedLoadController<RankedMovieListItemDto> {
  PagedRankedMovieController({
    required RankedMoviePageFetcher fetchPage,
    required this.subscribeMovie,
    required this.unsubscribeMovie,
    this.onSubscriptionChanged,
    int initialPage = 1,
    int pageSize = 24,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '排行榜加载失败，请稍后重试',
    String loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : super(
         fetchPage: fetchPage,
         initialPage: initialPage,
         pageSize: pageSize,
         loadMoreTriggerOffset: loadMoreTriggerOffset,
         initialLoadErrorText: initialLoadErrorText,
         loadMoreErrorText: loadMoreErrorText,
         scrollController: scrollController,
       );

  final MovieSubscriptionWriter subscribeMovie;
  final MovieUnsubscriptionWriter unsubscribeMovie;
  final MovieSubscriptionChangeReporter? onSubscriptionChanged;
  final Set<String> _updatingMovieNumbers = <String>{};

  bool isSubscriptionUpdating(String movieNumber) {
    return _updatingMovieNumbers.contains(movieNumber);
  }

  Future<MovieSubscriptionToggleResult> toggleSubscription({
    required String movieNumber,
  }) async {
    final index = mutableItems.indexWhere(
      (item) => item.movieNumber == movieNumber,
    );
    if (index == -1 || _updatingMovieNumbers.contains(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }

    final movie = mutableItems[index];
    _updatingMovieNumbers.add(movieNumber);
    notifyListenersSafely();

    try {
      if (movie.isSubscribed) {
        await unsubscribeMovie(movieNumber: movieNumber, deleteMedia: false);
        mutableItems[index] = movie.copyWith(isSubscribed: false);
        onSubscriptionChanged?.call(
          movieNumber: movieNumber,
          isSubscribed: false,
        );
        return const MovieSubscriptionToggleResult.unsubscribed();
      }

      await subscribeMovie(movieNumber: movieNumber);
      mutableItems[index] = movie.copyWith(isSubscribed: true);
      onSubscriptionChanged?.call(movieNumber: movieNumber, isSubscribed: true);
      return const MovieSubscriptionToggleResult.subscribed();
    } catch (error) {
      if (_isBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: movie.isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
        ),
      );
    } finally {
      _updatingMovieNumbers.remove(movieNumber);
      notifyListenersSafely();
    }
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }

  void applySubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    final index = mutableItems.indexWhere(
      (item) => item.movieNumber == movieNumber,
    );
    if (index == -1) {
      return;
    }
    final movie = mutableItems[index];
    if (movie.isSubscribed == isSubscribed) {
      return;
    }
    mutableItems[index] = movie.copyWith(isSubscribed: isSubscribed);
    notifyListenersSafely();
  }
}
