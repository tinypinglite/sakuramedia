import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

part 'movie_subscription_toggle_provider.g.dart';

/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。
@Riverpod(keepAlive: true)
class MovieSubscriptionToggle extends _$MovieSubscriptionToggle {
  @override
  Set<String> build() => const <String>{};

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
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '订阅影片失败' : '取消订阅影片失败',
        ),
      );
    } finally {
      state = Set<String>.unmodifiable(
        state.where((number) => number != normalizedMovieNumber),
      );
    }
  }
}
