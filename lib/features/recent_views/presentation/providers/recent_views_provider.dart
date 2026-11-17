import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_api_provider.dart';

part 'recent_views_provider.g.dart';

/// 最近浏览列表（最新在前，一次拉后端保留上限）。
///
/// - 单实例：概览区块只展示前若干条、更多页列全，共享同一份数据；
///   打开更多页不额外请求，刷新只发一次。
/// - 订阅变更广播到达时就地补丁订阅心状态，不整页重拉（浏览历史不因订阅状态变化而增删）。
@riverpod
class RecentViews extends _$RecentViews {
  @override
  Future<List<RecentViewEntryDto>> build() async {
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        _applyMovieSubscriptionChanges(changes);
      }
    });
    ref.listen(actorSubscriptionEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) {
        _applyActorSubscriptionChange(change);
      }
    });
    return ref.watch(recentViewsApiProvider).list();
  }

  void _applyMovieSubscriptionChanges(List<MovieSubscriptionChange> changes) {
    final current = state.value;
    if (current == null || changes.isEmpty) {
      return;
    }
    final isSubscribedByNumber = <String, bool>{
      for (final change in changes) change.movieNumber: change.isSubscribed,
    };
    var changed = false;
    final next = <RecentViewEntryDto>[];
    for (final entry in current) {
      final movie = entry.movie;
      final isSubscribed = movie == null
          ? null
          : isSubscribedByNumber[movie.movieNumber];
      if (movie == null ||
          isSubscribed == null ||
          movie.isSubscribed == isSubscribed) {
        next.add(entry);
        continue;
      }
      changed = true;
      next.add(
        entry.copyWith(movie: movie.copyWith(isSubscribed: isSubscribed)),
      );
    }
    if (changed) {
      state = AsyncData(List.unmodifiable(next));
    }
  }

  void _applyActorSubscriptionChange(ActorSubscriptionChange change) {
    final current = state.value;
    if (current == null) {
      return;
    }
    var changed = false;
    final next = <RecentViewEntryDto>[];
    for (final entry in current) {
      final actor = entry.actor;
      if (actor == null ||
          actor.id != change.actorId ||
          actor.isSubscribed == change.isSubscribed) {
        next.add(entry);
        continue;
      }
      changed = true;
      next.add(
        entry.copyWith(actor: actor.copyWith(isSubscribed: change.isSubscribed)),
      );
    }
    if (changed) {
      state = AsyncData(List.unmodifiable(next));
    }
  }
}
