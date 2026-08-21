import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/subscription_movie_list_item.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/optimistic_patch_mixin.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

abstract interface class SubscriptionMovieListState<
  S,
  T extends SubscriptionMovieListItem<T>
> {
  PagedListState<T> get paged;
  Set<String> get subscriptionUpdatingMovieNumbers;

  S applySubscriptionMutation({
    PagedListState<T>? paged,
    Set<String>? subscriptionUpdatingMovieNumbers,
  });
}

/// 两类影片列表共用的订阅变更语义。
mixin MovieSubscriptionMutationMixin<
  S extends SubscriptionMovieListState<S, T>,
  T extends SubscriptionMovieListItem<T>
>
    on PagedAsyncNotifierMixin<S, T>, OptimisticPatchMixin<S> {
  Future<MovieSubscriptionToggleResult> toggleSubscription(
    String movieNumber,
  ) async {
    final current = state.value;
    final movie = current?.paged.items
        .where((item) => item.movieNumber == movieNumber)
        .firstOrNull;
    if (movie == null || isInFlight(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }

    _setSubscriptionUpdating(movieNumber, true);
    final subscribe = !movie.isSubscribed;
    try {
      final api = ref.read(moviesApiProvider);
      if (subscribe) {
        await api.subscribeMovie(movieNumber: movieNumber);
      } else {
        await api.unsubscribeMovie(
          movieNumber: movieNumber,
          deleteMedia: false,
        );
      }
      if (isOptimisticPatchDisposed) {
        return const MovieSubscriptionToggleResult.ignored();
      }
      _patchSubscription(movieNumber, subscribe);
      _reportSubscriptionChanges(<MovieSubscriptionChange>[
        MovieSubscriptionChange(
          movieNumber: movieNumber,
          isSubscribed: subscribe,
        ),
      ]);
      return subscribe
          ? const MovieSubscriptionToggleResult.subscribed()
          : const MovieSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      if (isMovieSubscriptionBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '订阅影片失败' : '取消订阅影片失败',
        ),
      );
    } finally {
      if (!isOptimisticPatchDisposed) {
        _setSubscriptionUpdating(movieNumber, false);
      }
    }
  }

  Future<MovieSubscriptionBatchToggleResult> batchToggleSubscription({
    required Iterable<String> movieNumbers,
    required bool subscribe,
  }) async {
    final ordered = <String>[];
    final seen = <String>{};
    for (final movieNumber in movieNumbers) {
      if (movieNumber.isNotEmpty && seen.add(movieNumber)) {
        ordered.add(movieNumber);
      }
    }
    if (ordered.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: <String>[],
        skippedHasMediaNumbers: <String>[],
      );
    }

    final patched = <String>{};
    MovieSubscriptionBatchResultDto? response;
    final result =
        await withBatchOptimisticPatch<String, MovieSubscriptionBatchResultDto>(
          keys: ordered,
          apply: (current, applying) {
            final items = current.paged.items
                .map((item) {
                  if (!applying.contains(item.movieNumber) ||
                      item.isSubscribed == subscribe) {
                    return item;
                  }
                  patched.add(item.movieNumber);
                  return item.copyWithSubscriptionStatus(subscribe);
                })
                .toList(growable: false);
            return current.applySubscriptionMutation(
              paged: current.paged.copyWith(items: List.unmodifiable(items)),
            );
          },
          action: (numbers) async {
            final api = ref.read(moviesApiProvider);
            response = subscribe
                ? await api.batchSubscribeMovies(movieNumbers: numbers.toList())
                : await api.batchUnsubscribeMovies(
                    movieNumbers: numbers.toList(),
                  );
            return response!;
          },
          skippedFromResult: (value) => <String>{
            ...value.movieNumbersSkippedBecause(
              MovieSubscriptionSkipReason.movieNotFound,
            ),
            ...value.movieNumbersSkippedBecause(
              MovieSubscriptionSkipReason.hasMedia,
            ),
          },
          rollback: _restoreSubscriptionStatuses,
          errorMessageOf: (error) => apiErrorMessage(
            error,
            fallback: subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败',
          ),
        );
    if (result.errorMessage != null || response == null) {
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: ordered.length,
        message: result.errorMessage ?? (subscribe ? '批量订阅影片失败' : '批量取消订阅影片失败'),
      );
    }

    final resolved = response!;
    if (!isOptimisticPatchDisposed) {
      final acceptedPatched = result.accepted.intersection(patched);
      _reportSubscriptionChanges(<MovieSubscriptionChange>[
        for (final movieNumber in ordered)
          if (acceptedPatched.contains(movieNumber))
            MovieSubscriptionChange(
              movieNumber: movieNumber,
              isSubscribed: subscribe,
            ),
      ]);
    }
    return MovieSubscriptionBatchToggleResult(
      requestedCount: resolved.requestedCount,
      updatedCount: resolved.updatedCount,
      skippedMovieNotFoundNumbers: resolved.movieNumbersSkippedBecause(
        MovieSubscriptionSkipReason.movieNotFound,
      ),
      skippedHasMediaNumbers: resolved.movieNumbersSkippedBecause(
        MovieSubscriptionSkipReason.hasMedia,
      ),
    );
  }

  void applySubscriptionChanges(List<MovieSubscriptionChange> changes) {
    final current = state.value;
    if (current == null || changes.isEmpty) {
      return;
    }
    var paged = current.paged;
    for (final change in changes) {
      paged = shouldRemoveSubscriptionChange(change)
          ? paged.removeWhere((item) => item.movieNumber == change.movieNumber)
          : paged.patchWhere(
              (item) => item.movieNumber == change.movieNumber,
              (item) => item.copyWithSubscriptionStatus(change.isSubscribed),
            );
    }
    if (!identical(paged, current.paged)) {
      state = AsyncData(current.applySubscriptionMutation(paged: paged));
    }
  }

  bool shouldRemoveSubscriptionChange(MovieSubscriptionChange change) => false;

  void _patchSubscription(String movieNumber, bool isSubscribed) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final paged = current.paged.patchWhere(
      (item) => item.movieNumber == movieNumber,
      (item) => item.copyWithSubscriptionStatus(isSubscribed),
    );
    if (!identical(paged, current.paged)) {
      state = AsyncData(current.applySubscriptionMutation(paged: paged));
    }
  }

  void _setSubscriptionUpdating(String movieNumber, bool updating) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final numbers = Set<String>.of(current.subscriptionUpdatingMovieNumbers);
    final changed = updating
        ? numbers.add(movieNumber)
        : numbers.remove(movieNumber);
    if (changed) {
      state = AsyncData(
        current.applySubscriptionMutation(
          subscriptionUpdatingMovieNumbers: numbers,
        ),
      );
    }
  }

  S _restoreSubscriptionStatuses(
    S current,
    S original,
    Set<String> movieNumbers,
  ) {
    if (movieNumbers.isEmpty) {
      return current;
    }
    final originals = <String, T>{
      for (final item in original.paged.items) item.movieNumber: item,
    };
    final items = current.paged.items
        .map(
          (item) => movieNumbers.contains(item.movieNumber)
              ? (originals[item.movieNumber] ?? item)
              : item,
        )
        .toList(growable: false);
    return current.applySubscriptionMutation(
      paged: current.paged.copyWith(items: List.unmodifiable(items)),
    );
  }

  void _reportSubscriptionChanges(List<MovieSubscriptionChange> changes) {
    if (changes.isEmpty || isOptimisticPatchDisposed) {
      return;
    }
    final broadcaster = ref.read(movieSubscriptionEventsProvider.notifier);
    if (changes.length == 1) {
      final change = changes.single;
      broadcaster.reportChange(
        movieNumber: change.movieNumber,
        isSubscribed: change.isSubscribed,
      );
      return;
    }
    broadcaster.reportBatch(changes);
  }
}
