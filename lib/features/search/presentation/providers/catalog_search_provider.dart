import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_search_stream_update.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/series_import/movie_search_stream_update.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';

part 'catalog_search_provider.g.dart';

/// 一次性目录搜索的按路由缓存状态。
///
/// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
/// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。
@riverpod
class CatalogSearch extends _$CatalogSearch {
  KeepAliveLink? _cacheLink;
  StreamSubscription<Object?>? _activeSearchSubscription;
  int _requestVersion = 0;
  bool _isDisposed = false;

  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  CatalogSearchState build(CatalogSearchScope scope) {
    _cacheLink ??= ref.keepAlive();
    ref.onDispose(() {
      _isDisposed = true;
      unawaited(_activeSearchSubscription?.cancel());
      _activeSearchSubscription = null;
    });
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final changes = next.value;
      if (changes != null) {
        applyMovieSubscriptionChanges(changes);
      }
    });
    return CatalogSearchState.initial;
  }

  void bootstrap({
    required String initialQuery,
    required bool initialUseOnlineSearch,
  }) {
    if (state.hasBootstrapped) {
      return;
    }
    state = state.copyWith(
      useOnlineSearch: initialUseOnlineSearch,
      hasBootstrapped: true,
    );
    if (initialQuery.trim().isNotEmpty) {
      unawaited(submit(initialQuery, useOnlineSearch: initialUseOnlineSearch));
    }
  }

  void setUseOnlineSearch(bool value) {
    if (state.useOnlineSearch == value) {
      return;
    }
    state = state.copyWith(useOnlineSearch: value);
  }

  Future<void> submit(String rawQuery, {required bool useOnlineSearch}) async {
    final trimmed = rawQuery.trim();
    await _cancelActiveSearch();
    if (_isDisposed) {
      return;
    }
    if (trimmed.isEmpty) {
      state = state.copyWith(
        query: '',
        isLoading: false,
        errorMessage: null,
        streamStatus: null,
        useOnlineSearch: useOnlineSearch,
      );
      return;
    }

    final requestVersion = ++_requestVersion;
    state = state.copyWith(
      query: trimmed,
      isLoading: true,
      isOnlineSearchActive: useOnlineSearch,
      useOnlineSearch: useOnlineSearch,
      errorMessage: null,
      streamStatus: null,
    );

    try {
      final parsed = await ref
          .read(moviesApiProvider)
          .parseMovieNumber(query: trimmed);
      if (!_isCurrent(requestVersion)) {
        return;
      }

      var isActualOnlineSearch = useOnlineSearch;
      if (parsed.parsed && (parsed.movieNumber?.isNotEmpty ?? false)) {
        state = state.copyWith(
          lastResolvedKind: CatalogSearchKind.movies,
          activeKind: CatalogSearchKind.movies,
          isOnlineSearchActive: isActualOnlineSearch,
        );
        if (isActualOnlineSearch) {
          state = state.copyWith(
            streamStatus: const CatalogSearchStreamStatus(
              message: '正在从外部数据源搜索影片',
              isRunning: true,
              isFailure: false,
            ),
          );
          await _consumeMovieOnlineSearch(
            requestVersion: requestVersion,
            movieNumber: parsed.movieNumber!,
          );
        } else {
          final results = await ref
              .read(moviesApiProvider)
              .searchLocalMovies(movieNumber: parsed.movieNumber!);
          if (!_isCurrent(requestVersion)) {
            return;
          }
          state = state.copyWith(movieResults: results, actorResults: const []);
        }
      } else {
        state = state.copyWith(
          lastResolvedKind: CatalogSearchKind.actors,
          activeKind: CatalogSearchKind.actors,
          isOnlineSearchActive: true,
        );
        isActualOnlineSearch = true;
        state = state.copyWith(
          streamStatus: const CatalogSearchStreamStatus(
            message: '正在从外部数据源搜索女优',
            isRunning: true,
            isFailure: false,
          ),
        );
        await _consumeActorOnlineSearch(
          requestVersion: requestVersion,
          actorName: trimmed,
        );
      }
    } catch (error) {
      if (!_isCurrent(requestVersion)) {
        return;
      }
      state = state.copyWith(
        movieResults: const [],
        actorResults: const [],
        errorMessage: apiErrorMessage(error, fallback: '搜索失败，请稍后重试'),
      );
    } finally {
      if (_isCurrent(requestVersion) && !state.isOnlineSearchActive) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void setActiveKind(CatalogSearchKind kind) {
    if (state.activeKind == kind) {
      return;
    }
    state = state.copyWith(activeKind: kind);
  }

  Future<MovieSubscriptionToggleResult> toggleMovieSubscription(
    String movieNumber,
  ) async {
    final movie =
        state.movieResults
            .where((item) => item.movieNumber == movieNumber)
            .firstOrNull;
    if (movie == null || state.isMovieSubscriptionUpdating(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    _setMovieSubscriptionUpdating(movieNumber, true);
    final subscribe = !movie.isSubscribed;
    try {
      final api = ref.read(moviesApiProvider);
      if (subscribe) {
        await api.subscribeMovie(movieNumber: movieNumber);
      } else {
        await api.unsubscribeMovie(movieNumber: movieNumber);
      }
      if (_isDisposed) {
        return const MovieSubscriptionToggleResult.ignored();
      }
      _patchMovieSubscription(movieNumber, subscribe);
      _reportMovieSubscriptionChange(
        MovieSubscriptionChange(
          movieNumber: movieNumber,
          isSubscribed: subscribe,
        ),
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
      if (!_isDisposed) {
        _setMovieSubscriptionUpdating(movieNumber, false);
      }
    }
  }

  Future<ActorSubscriptionToggleResult> toggleActorSubscription(
    int actorId,
  ) async {
    final actor =
        state.actorResults.where((item) => item.id == actorId).firstOrNull;
    if (actor == null || state.isActorSubscriptionUpdating(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }
    _setActorSubscriptionUpdating(actorId, true);
    final subscribe = !actor.isSubscribed;
    try {
      final api = ref.read(actorsApiProvider);
      if (subscribe) {
        await api.subscribeActor(actorId: actorId);
      } else {
        await api.unsubscribeActor(actorId: actorId);
      }
      if (_isDisposed) {
        return const ActorSubscriptionToggleResult.ignored();
      }
      final items = state.actorResults
          .map(
            (item) =>
                item.id == actorId
                    ? item.copyWith(isSubscribed: subscribe)
                    : item,
          )
          .toList(growable: false);
      state = state.copyWith(actorResults: items);
      return subscribe
          ? const ActorSubscriptionToggleResult.subscribed()
          : const ActorSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      return ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '订阅女优失败' : '取消订阅女优失败',
        ),
      );
    } finally {
      if (!_isDisposed) {
        _setActorSubscriptionUpdating(actorId, false);
      }
    }
  }

  void applyMovieSubscriptionChanges(List<MovieSubscriptionChange> changes) {
    if (changes.isEmpty || _isDisposed) {
      return;
    }
    for (final change in changes) {
      applyMovieSubscriptionChange(
        movieNumber: change.movieNumber,
        isSubscribed: change.isSubscribed,
      );
    }
  }

  void applyMovieSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
    bool removeIfUnsubscribed = false,
  }) {
    if (_isDisposed) {
      return;
    }
    final index = state.movieResults.indexWhere(
      (movie) => movie.movieNumber == movieNumber,
    );
    if (index < 0) {
      return;
    }
    if (!isSubscribed && removeIfUnsubscribed) {
      final items = List.of(state.movieResults)..removeAt(index);
      state = state.copyWith(movieResults: items);
      return;
    }
    if (state.movieResults[index].isSubscribed == isSubscribed) {
      return;
    }
    final items = List.of(state.movieResults);
    items[index] = items[index].copyWith(isSubscribed: isSubscribed);
    state = state.copyWith(movieResults: items);
  }

  Future<void> _consumeMovieOnlineSearch({
    required int requestVersion,
    required String movieNumber,
  }) async {
    final completer = Completer<void>();
    final subscription = ref
        .read(moviesApiProvider)
        .searchOnlineMoviesStream(movieNumber: movieNumber)
        .listen(
          (update) {
            if (_isCurrent(requestVersion)) {
              _applyMovieSearchStreamUpdate(update);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isCurrent(requestVersion)) {
              state = state.copyWith(
                movieResults: const [],
                actorResults: const [],
                errorMessage: apiErrorMessage(error, fallback: '搜索失败，请稍后重试'),
                isLoading: false,
              );
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onDone: () {
            if (_isCurrent(requestVersion)) {
              state = state.copyWith(isLoading: false);
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          cancelOnError: false,
        );
    _activeSearchSubscription = subscription;
    await completer.future;
    if (identical(_activeSearchSubscription, subscription)) {
      _activeSearchSubscription = null;
    }
  }

  Future<void> _consumeActorOnlineSearch({
    required int requestVersion,
    required String actorName,
  }) async {
    final completer = Completer<void>();
    final subscription = ref
        .read(actorsApiProvider)
        .searchOnlineActorsStream(actorName: actorName)
        .listen(
          (update) {
            if (_isCurrent(requestVersion)) {
              _applyActorSearchStreamUpdate(update);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isCurrent(requestVersion)) {
              state = state.copyWith(
                movieResults: const [],
                actorResults: const [],
                errorMessage: apiErrorMessage(error, fallback: '搜索失败，请稍后重试'),
                isLoading: false,
              );
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onDone: () {
            if (_isCurrent(requestVersion)) {
              state = state.copyWith(isLoading: false);
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          cancelOnError: false,
        );
    _activeSearchSubscription = subscription;
    await completer.future;
    if (identical(_activeSearchSubscription, subscription)) {
      _activeSearchSubscription = null;
    }
  }

  void _applyMovieSearchStreamUpdate(MovieSearchStreamUpdate update) {
    state = state.copyWith(
      streamStatus: CatalogSearchStreamStatus(
        message: update.message,
        isRunning: !update.isComplete,
        isFailure:
            update.isComplete &&
            update.success == false &&
            !_isNotFoundReason(update.reason),
        current: update.current,
        total: update.total,
        stats: update.stats,
      ),
      movieResults: update.isComplete ? update.results : null,
      actorResults: update.isComplete ? const [] : null,
      errorMessage: update.isComplete ? null : state.errorMessage,
    );
  }

  void _applyActorSearchStreamUpdate(ActorSearchStreamUpdate update) {
    state = state.copyWith(
      streamStatus: CatalogSearchStreamStatus(
        message: update.message,
        isRunning: !update.isComplete,
        isFailure:
            update.isComplete &&
            update.success == false &&
            !_isNotFoundReason(update.reason),
        current: update.current,
        total: update.total,
        stats: update.stats,
      ),
      actorResults: update.isComplete ? update.results : null,
      movieResults: update.isComplete ? const [] : null,
      errorMessage: update.isComplete ? null : state.errorMessage,
    );
  }

  Future<void> _cancelActiveSearch() async {
    final subscription = _activeSearchSubscription;
    _activeSearchSubscription = null;
    await subscription?.cancel();
  }

  bool _isCurrent(int requestVersion) =>
      !_isDisposed && requestVersion == _requestVersion;

  bool _isNotFoundReason(String? reason) =>
      reason == 'movie_not_found' || reason == 'actor_not_found';

  void _patchMovieSubscription(String movieNumber, bool isSubscribed) {
    applyMovieSubscriptionChanges(<MovieSubscriptionChange>[
      MovieSubscriptionChange(
        movieNumber: movieNumber,
        isSubscribed: isSubscribed,
      ),
    ]);
  }

  void _setMovieSubscriptionUpdating(String movieNumber, bool updating) {
    final next = Set<String>.of(state.updatingMovieNumbers);
    final changed = updating ? next.add(movieNumber) : next.remove(movieNumber);
    if (changed) {
      state = state.copyWith(updatingMovieNumbers: next);
    }
  }

  void _setActorSubscriptionUpdating(int actorId, bool updating) {
    final next = Set<int>.of(state.updatingActorIds);
    final changed = updating ? next.add(actorId) : next.remove(actorId);
    if (changed) {
      state = state.copyWith(updatingActorIds: next);
    }
  }

  void _reportMovieSubscriptionChange(MovieSubscriptionChange change) {
    if (_isDisposed) {
      return;
    }
    ref
        .read(movieSubscriptionEventsProvider.notifier)
        .reportChange(
          movieNumber: change.movieNumber,
          isSubscribed: change.isSubscribed,
        );
  }
}
