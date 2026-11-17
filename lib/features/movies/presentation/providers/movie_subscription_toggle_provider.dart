import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

part 'movie_subscription_toggle_provider.g.dart';

typedef MovieForceUnsubscribeProgress = ({double? value, String message});

/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。
@Riverpod(keepAlive: true)
class MovieSubscriptionToggle extends _$MovieSubscriptionToggle {
  @override
  Set<String> build() => const <String>{};

  /// 前端串行删除媒体，全部成功后仅发送一次批量取消订阅请求。
  Future<MovieSubscriptionBatchToggleResult> forceUnsubscribeBatch(
    Iterable<String> movieNumbers, {
    void Function(MovieForceUnsubscribeProgress progress)? onProgress,
  }) async {
    final numbers = movieNumbers.where((number) => number.isNotEmpty).toSet();
    if (numbers.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: [],
        skippedHasMediaNumbers: [],
      );
    }
    final l10n = ref.read(appLocalizationsProvider);
    if (numbers.any(state.contains)) {
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: numbers.length,
        message: l10n.movieProviderForceUnsubscribeBusy,
      );
    }
    state = Set.unmodifiable({...state, ...numbers});
    var deletedCount = 0;
    var step = l10n.movieProviderReadMovieMediaFailed;
    try {
      final api = ref.read(moviesApiProvider);
      final mediaApi = ref.read(mediaApiProvider);
      final movies = <MovieDetailDto>[];
      for (final number in numbers) {
        step = l10n.movieProviderReadMovieMediaForFailed(number);
        onProgress?.call((
          value: null,
          message: l10n.movieProviderReadingMediaList(
            movies.length + 1,
            numbers.length,
          ),
        ));
        movies.add(await api.getMovieDetail(movieNumber: number));
      }
      final total = movies.fold<int>(
        0,
        (count, movie) => count + movie.mediaItems.length,
      );
      for (final movie in movies) {
        final number = movie.movieNumber;
        try {
          for (final media in movie.mediaItems) {
            step = l10n.movieProviderDeleteMovieMediaFailed(
              number,
              media.mediaId,
            );
            onProgress?.call((
              value: deletedCount / total,
              message: l10n.movieProviderMediaDeletedProgress(
                deletedCount,
                total,
                number,
              ),
            ));
            await mediaApi.deleteMedia(mediaId: media.mediaId);
            deletedCount++;
            onProgress?.call((
              value: deletedCount / total,
              message: l10n.movieProviderMediaDeletedProgress(
                deletedCount,
                total,
                number,
              ),
            ));
          }
        } catch (_) {
          // 已删除的媒体不能回滚，尽力同步这一部影片的实际状态。
          try {
            await _reportMediaState(number);
          } catch (_) {}
          rethrow;
        }
        step = l10n.movieProviderRefreshMovieMediaFailed(number);
        await _reportMediaState(number);
      }
      step = l10n.movieProviderMediaClearedUnsubscribeFailed;
      onProgress?.call((
        value: 1,
        message: l10n.movieProviderMediaDeletedUnsubscribing(
          deletedCount,
          total,
        ),
      ));
      final response = await api.batchUnsubscribeMovies(
        movieNumbers: numbers.toList(),
      );
      final skipped = response.skipped.map((item) => item.movieNumber).toSet();
      ref.read(movieSubscriptionEventsProvider.notifier).reportBatch([
        for (final number in numbers)
          if (!skipped.contains(number))
            MovieSubscriptionChange(
              movieNumber: number,
              isSubscribed: false,
              fromBatch: true,
            ),
      ]);
      return MovieSubscriptionBatchToggleResult(
        requestedCount: response.requestedCount,
        updatedCount: response.updatedCount,
        skippedMovieNotFoundNumbers: response.movieNumbersSkippedBecause(
          MovieSubscriptionSkipReason.movieNotFound,
        ),
        skippedHasMediaNumbers: response.movieNumbersSkippedBecause(
          MovieSubscriptionSkipReason.hasMedia,
        ),
      );
    } catch (error) {
      final reason = ref.apiErrorMessage(
        error,
        fallback: ref.read(appLocalizationsProvider).errorRetryLater,
      );
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: numbers.length,
        message: l10n.movieProviderForceUnsubscribeStopped(
          step,
          reason,
          deletedCount,
        ),
      );
    } finally {
      if (ref.mounted) {
        state = Set.unmodifiable(state.difference(numbers));
      }
    }
  }

  Future<void> _reportMediaState(String movieNumber) async {
    final movie = await ref
        .read(moviesApiProvider)
        .getMovieDetail(movieNumber: movieNumber);
    ref
        .read(movieMediaEventsProvider.notifier)
        .reportChange(
          MovieMediaChange(
            movieNumber: movieNumber,
            canPlay: movie.canPlay,
            isSubscribed: movie.isSubscribed,
          ),
        );
  }

  Future<MovieSubscriptionToggleResult> toggle({
    required String movieNumber,
    required bool isSubscribed,
  }) async {
    final normalizedMovieNumber = movieNumber.trim();
    if (normalizedMovieNumber.isEmpty ||
        state.contains(normalizedMovieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    state = Set<String>.unmodifiable(<String>{...state, normalizedMovieNumber});
    final subscribe = !isSubscribed;
    try {
      final api = ref.read(moviesApiProvider);
      if (subscribe) {
        await api.subscribeMovie(movieNumber: normalizedMovieNumber);
      } else {
        await api.unsubscribeMovie(
          movieNumber: normalizedMovieNumber,
          deleteMedia: false,
        );
      }
      ref
          .read(movieSubscriptionEventsProvider.notifier)
          .reportChange(
            movieNumber: normalizedMovieNumber,
            isSubscribed: subscribe,
          );
      return subscribe
          ? const MovieSubscriptionToggleResult.subscribed()
          : const MovieSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      if (isMovieSubscriptionBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      final l10n = ref.read(appLocalizationsProvider);
      return MovieSubscriptionToggleResult.failed(
        message: ref.apiErrorMessage(
          error,
          fallback: subscribe
              ? l10n.movieProviderSubscribeMovieFailed
              : l10n.errorUnsubscribeMovieFailed,
        ),
      );
    } finally {
      state = Set<String>.unmodifiable(
        state.where((number) => number != normalizedMovieNumber),
      );
    }
  }
}
