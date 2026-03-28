import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/data/actor_search_stream_update.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/data/movie_search_stream_update.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';

enum CatalogSearchKind { movies, actors }

class CatalogSearchController extends ChangeNotifier {
  CatalogSearchController({
    required MoviesApi moviesApi,
    required ActorsApi actorsApi,
  }) : _moviesApi = moviesApi,
       _actorsApi = actorsApi;

  final MoviesApi _moviesApi;
  final ActorsApi _actorsApi;

  String _query = '';
  CatalogSearchKind _activeKind = CatalogSearchKind.movies;
  CatalogSearchKind? _lastResolvedKind;
  bool _isLoading = false;
  bool _isOnlineSearchActive = false;
  String? _errorMessage;
  CatalogSearchStreamStatus? _streamStatus;
  List<MovieListItemDto> _movieResults = const <MovieListItemDto>[];
  List<ActorListItemDto> _actorResults = const <ActorListItemDto>[];
  final Set<String> _updatingMovieNumbers = <String>{};
  final Set<int> _updatingActorIds = <int>{};
  int _requestVersion = 0;
  StreamSubscription<Object?>? _activeSearchSubscription;
  bool _isDisposed = false;

  String get query => _query;
  CatalogSearchKind get activeKind => _activeKind;
  CatalogSearchKind? get lastResolvedKind => _lastResolvedKind;
  bool get isLoading => _isLoading;
  bool get isOnlineSearchActive => _isOnlineSearchActive;
  String? get errorMessage => _errorMessage;
  CatalogSearchStreamStatus? get streamStatus => _streamStatus;
  List<MovieListItemDto> get movieResults => _movieResults;
  List<ActorListItemDto> get actorResults => _actorResults;

  bool isMovieSubscriptionUpdating(String movieNumber) {
    return _updatingMovieNumbers.contains(movieNumber);
  }

  bool isActorSubscriptionUpdating(int actorId) {
    return _updatingActorIds.contains(actorId);
  }

  Future<void> submit(String rawQuery, {required bool useOnlineSearch}) async {
    final trimmed = rawQuery.trim();
    await _cancelActiveSearch();
    if (trimmed.isEmpty) {
      _query = '';
      _isLoading = false;
      _errorMessage = null;
      _streamStatus = null;
      return;
    }

    final requestVersion = ++_requestVersion;
    _query = trimmed;
    _isLoading = true;
    _isOnlineSearchActive = useOnlineSearch;
    _errorMessage = null;
    _streamStatus = null;
    _notifyListenersSafely();

    try {
      final parsed = await _moviesApi.parseMovieNumber(query: trimmed);
      if (requestVersion != _requestVersion) {
        return;
      }

      // 女优本地搜索接口已下线，实际执行策略要按解析结果重新决定。
      var isActualOnlineSearch = useOnlineSearch;

      if (parsed.parsed && (parsed.movieNumber?.isNotEmpty ?? false)) {
        _lastResolvedKind = CatalogSearchKind.movies;
        _activeKind = CatalogSearchKind.movies;
        _isOnlineSearchActive = isActualOnlineSearch;
        _notifyListenersSafely();

        if (isActualOnlineSearch) {
          _streamStatus = const CatalogSearchStreamStatus(
            message: '正在从外部数据源搜索影片',
            isRunning: true,
            isFailure: false,
          );
          _notifyListenersSafely();
          await _consumeMovieOnlineSearch(
            requestVersion: requestVersion,
            movieNumber: parsed.movieNumber!,
          );
        } else {
          final results = await _moviesApi.searchLocalMovies(
            movieNumber: parsed.movieNumber!,
          );
          if (requestVersion != _requestVersion) {
            return;
          }
          _movieResults = results;
          _actorResults = const <ActorListItemDto>[];
        }
      } else {
        _lastResolvedKind = CatalogSearchKind.actors;
        _activeKind = CatalogSearchKind.actors;
        // 女优搜索统一走在线源，页面开关只继续影响影片搜索。
        isActualOnlineSearch = true;
        _isOnlineSearchActive = true;
        _notifyListenersSafely();

        _streamStatus = const CatalogSearchStreamStatus(
          message: '正在从外部数据源搜索女优',
          isRunning: true,
          isFailure: false,
        );
        _notifyListenersSafely();
        await _consumeActorOnlineSearch(
          requestVersion: requestVersion,
          actorName: trimmed,
        );
      }
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }
      _movieResults = const <MovieListItemDto>[];
      _actorResults = const <ActorListItemDto>[];
      _errorMessage = apiErrorMessage(error, fallback: '搜索失败，请稍后重试');
    } finally {
      if (requestVersion == _requestVersion && !_isOnlineSearchActive) {
        _isLoading = false;
        _notifyListenersSafely();
      }
    }
  }

  void setActiveKind(CatalogSearchKind kind) {
    if (_activeKind == kind) {
      return;
    }
    _activeKind = kind;
    _notifyListenersSafely();
  }

  Future<void> _consumeMovieOnlineSearch({
    required int requestVersion,
    required String movieNumber,
  }) async {
    final completer = Completer<void>();

    final subscription = _moviesApi
        .searchOnlineMoviesStream(movieNumber: movieNumber)
        .listen(
          (update) {
            if (requestVersion != _requestVersion) {
              return;
            }
            _applyMovieSearchStreamUpdate(update);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (requestVersion != _requestVersion) {
              if (!completer.isCompleted) {
                completer.complete();
              }
              return;
            }
            _movieResults = const <MovieListItemDto>[];
            _actorResults = const <ActorListItemDto>[];
            _errorMessage = apiErrorMessage(error, fallback: '搜索失败，请稍后重试');
            _isLoading = false;
            _notifyListenersSafely();
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onDone: () {
            if (requestVersion == _requestVersion) {
              _isLoading = false;
              _notifyListenersSafely();
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

    final subscription = _actorsApi
        .searchOnlineActorsStream(actorName: actorName)
        .listen(
          (update) {
            if (requestVersion != _requestVersion) {
              return;
            }
            _applyActorSearchStreamUpdate(update);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (requestVersion != _requestVersion) {
              if (!completer.isCompleted) {
                completer.complete();
              }
              return;
            }
            _movieResults = const <MovieListItemDto>[];
            _actorResults = const <ActorListItemDto>[];
            _errorMessage = apiErrorMessage(error, fallback: '搜索失败，请稍后重试');
            _isLoading = false;
            _notifyListenersSafely();
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onDone: () {
            if (requestVersion == _requestVersion) {
              _isLoading = false;
              _notifyListenersSafely();
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
    _streamStatus = CatalogSearchStreamStatus(
      message: update.message,
      isRunning: !update.isComplete,
      isFailure:
          update.isComplete &&
          update.success == false &&
          !_isNotFoundReason(update.reason),
      current: update.current,
      total: update.total,
      stats: update.stats,
    );
    if (update.isComplete) {
      _movieResults = update.results;
      _actorResults = const <ActorListItemDto>[];
      _errorMessage = null;
    }
    _notifyListenersSafely();
  }

  void _applyActorSearchStreamUpdate(ActorSearchStreamUpdate update) {
    _streamStatus = CatalogSearchStreamStatus(
      message: update.message,
      isRunning: !update.isComplete,
      isFailure:
          update.isComplete &&
          update.success == false &&
          !_isNotFoundReason(update.reason),
      current: update.current,
      total: update.total,
      stats: update.stats,
    );
    if (update.isComplete) {
      _actorResults = update.results;
      _movieResults = const <MovieListItemDto>[];
      _errorMessage = null;
    }
    _notifyListenersSafely();
  }

  Future<void> _cancelActiveSearch() async {
    final subscription = _activeSearchSubscription;
    _activeSearchSubscription = null;
    await subscription?.cancel();
  }

  bool _isNotFoundReason(String? reason) {
    return reason == 'movie_not_found' || reason == 'actor_not_found';
  }

  Future<MovieSubscriptionToggleResult> toggleMovieSubscription({
    required String movieNumber,
  }) async {
    final index = _movieResults.indexWhere(
      (movie) => movie.movieNumber == movieNumber,
    );
    if (index == -1 || _updatingMovieNumbers.contains(movieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }

    final movie = _movieResults[index];
    _updatingMovieNumbers.add(movieNumber);
    _notifyListenersSafely();

    try {
      if (movie.isSubscribed) {
        await _moviesApi.unsubscribeMovie(movieNumber: movieNumber);
        _movieResults = List<MovieListItemDto>.of(_movieResults)
          ..[index] = movie.copyWith(isSubscribed: false);
        return const MovieSubscriptionToggleResult.unsubscribed();
      } else {
        await _moviesApi.subscribeMovie(movieNumber: movieNumber);
        _movieResults = List<MovieListItemDto>.of(_movieResults)
          ..[index] = movie.copyWith(isSubscribed: true);
        return const MovieSubscriptionToggleResult.subscribed();
      }
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
      _notifyListenersSafely();
    }
  }

  bool _isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }

  Future<ActorSubscriptionToggleResult> toggleActorSubscription({
    required int actorId,
  }) async {
    final index = _actorResults.indexWhere((actor) => actor.id == actorId);
    if (index == -1 || _updatingActorIds.contains(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }

    final actor = _actorResults[index];
    _updatingActorIds.add(actorId);
    _notifyListenersSafely();

    try {
      if (actor.isSubscribed) {
        await _actorsApi.unsubscribeActor(actorId: actorId);
        _actorResults = List<ActorListItemDto>.of(_actorResults)
          ..[index] = actor.copyWith(isSubscribed: false);
        return const ActorSubscriptionToggleResult.unsubscribed();
      }

      await _actorsApi.subscribeActor(actorId: actorId);
      _actorResults = List<ActorListItemDto>.of(_actorResults)
        ..[index] = actor.copyWith(isSubscribed: true);
      return const ActorSubscriptionToggleResult.subscribed();
    } catch (error) {
      return ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: actor.isSubscribed ? '取消订阅女优失败' : '订阅女优失败',
        ),
      );
    } finally {
      _updatingActorIds.remove(actorId);
      _notifyListenersSafely();
    }
  }

  void _notifyListenersSafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeSearchSubscription?.cancel();
    super.dispose();
  }
}
