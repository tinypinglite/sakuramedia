import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

typedef MovieSummaryPageFetcher =
    Future<PaginatedResponseDto<MovieListItemDto>> Function(
      int page,
      int pageSize,
    );

typedef MovieSubscriptionWriter =
    Future<void> Function({required String movieNumber});

typedef MovieUnsubscriptionWriter =
    Future<void> Function({required String movieNumber, bool deleteMedia});

typedef MovieSubscriptionChangeReporter =
    void Function({required String movieNumber, required bool isSubscribed});

enum MovieSubscriptionToggleStatus {
  subscribed,
  unsubscribed,
  blockedByMedia,
  failed,
  ignored,
}

class MovieSubscriptionToggleResult {
  const MovieSubscriptionToggleResult({required this.status, this.message});

  const MovieSubscriptionToggleResult.subscribed()
    : this(status: MovieSubscriptionToggleStatus.subscribed);

  const MovieSubscriptionToggleResult.unsubscribed()
    : this(status: MovieSubscriptionToggleStatus.unsubscribed);

  const MovieSubscriptionToggleResult.blockedByMedia()
    : this(status: MovieSubscriptionToggleStatus.blockedByMedia);

  const MovieSubscriptionToggleResult.failed({required String message})
    : this(status: MovieSubscriptionToggleStatus.failed, message: message);

  const MovieSubscriptionToggleResult.ignored()
    : this(status: MovieSubscriptionToggleStatus.ignored);

  final MovieSubscriptionToggleStatus status;
  final String? message;
}

class PagedMovieSummaryController
    extends PagedLoadController<MovieListItemDto> {
  PagedMovieSummaryController({
    required MovieSummaryPageFetcher fetchPage,
    required this.subscribeMovie,
    required this.unsubscribeMovie,
    this.onSubscriptionChanged,
    int initialPage = 1,
    int pageSize = 24,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '最新入库影片加载失败，请稍后重试',
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

  void removeItem(String movieNumber) {
    final index = mutableItems.indexWhere(
      (item) => item.movieNumber == movieNumber,
    );
    if (index == -1) {
      return;
    }
    mutableItems.removeAt(index);
    mutableTotal = (mutableTotal - 1).clamp(0, mutableTotal);
    notifyListenersSafely();
  }

  void applySubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
    bool removeIfUnsubscribed = false,
  }) {
    final index = mutableItems.indexWhere(
      (item) => item.movieNumber == movieNumber,
    );
    if (index == -1) {
      return;
    }
    if (!isSubscribed && removeIfUnsubscribed) {
      removeItem(movieNumber);
      return;
    }

    final movie = mutableItems[index];
    if (movie.isSubscribed == isSubscribed) {
      return;
    }
    mutableItems[index] = movie.copyWith(isSubscribed: isSubscribed);
    notifyListenersSafely();
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }
}
