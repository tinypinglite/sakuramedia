import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_session_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_api_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';

part 'image_search_provider.g.dart';

/// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。
@riverpod
class ImageSearch extends _$ImageSearch {
  KeepAliveLink? _cacheLink;
  int _searchVersion = 0;
  int _actorsVersion = 0;
  bool _isDisposed = false;

  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  ImageSearchState build(ImageSearchScope scope) {
    _cacheLink ??= ref.keepAlive();
    ref.onDispose(() {
      _isDisposed = true;
      _searchVersion += 1;
      _actorsVersion += 1;
    });
    return ImageSearchState();
  }

  void initialize(ImageSearchCurrentMovieScope initialCurrentMovieScope) {
    if (state.hasInitialized) {
      return;
    }
    state = state.copyWith(
      filterState: state.filterState.copyWith(
        currentMovieScope: initialCurrentMovieScope,
      ),
      hasInitialized: true,
    );
  }

  void updateFilter(ImageSearchFilterState filter) {
    state = state.copyWith(filterState: filter);
  }

  void setSource({
    required Uint8List fileBytes,
    required String fileName,
    String? mimeType,
    Object? bootstrappedSourceSignature,
  }) {
    _searchVersion += 1;
    state = state.copyWith(
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      sessionId: null,
      nextCursor: null,
      expiresAt: null,
      items: const <ImageSearchResultItemDto>[],
      isSearching: false,
      isLoadingMore: false,
      isResolvingActorMovieIds: false,
      errorMessage: null,
      bootstrappedSourceSignature: bootstrappedSourceSignature,
    );
  }

  void togglePreviewExpanded() {
    state = state.copyWith(isPreviewExpanded: !state.isPreviewExpanded);
  }

  void toggleFilterExpanded() {
    state = state.copyWith(isFilterExpanded: !state.isFilterExpanded);
  }

  Future<void> ensureSubscribedActorsLoaded() async {
    if (state.isLoadingSubscribedActors || state.subscribedActors.isNotEmpty) {
      return;
    }
    final requestVersion = ++_actorsVersion;
    state = state.copyWith(
      isLoadingSubscribedActors: true,
      subscribedActorsErrorMessage: null,
    );

    try {
      final actors = <ActorListItemDto>[];
      var page = 1;
      const pageSize = 200;
      while (true) {
        final response = await ref
            .read(actorsApiProvider)
            .getActors(
              subscriptionStatus: ActorSubscriptionStatus.subscribed,
              gender: ActorGender.all,
              page: page,
              pageSize: pageSize,
            );
        if (!_isCurrentActorsRequest(requestVersion)) {
          return;
        }
        actors.addAll(response.items);
        if (actors.length >= response.total || response.items.isEmpty) {
          break;
        }
        page += 1;
      }
      state = state.copyWith(subscribedActors: actors);
    } catch (_) {
      if (_isCurrentActorsRequest(requestVersion)) {
        state = state.copyWith(subscribedActorsErrorMessage: '加载已订阅女优失败');
      }
    } finally {
      if (_isCurrentActorsRequest(requestVersion)) {
        state = state.copyWith(isLoadingSubscribedActors: false);
      }
    }
  }

  Future<void> search({
    ImageSearchFilterState filter = const ImageSearchFilterState(),
    String? currentMovieNumber,
  }) async {
    if (!state.hasSource || state.isSearching) {
      return;
    }

    final requestVersion = ++_searchVersion;
    state = state.copyWith(
      activeFilter: filter,
      activeCurrentMovieNumber: _normalizeCurrentMovieNumber(
        currentMovieNumber,
      ),
      isSearching: true,
      isLoadingMore: false,
      errorMessage: null,
    );

    try {
      final resolved = await _resolveMovieFilters(filter, requestVersion);
      if (!_isCurrentSearch(requestVersion)) {
        return;
      }
      if (resolved == null) {
        state = state.copyWith(
          errorMessage: '所选女优下没有可用于筛选的影片',
          items: const <ImageSearchResultItemDto>[],
          sessionId: null,
          nextCursor: null,
          expiresAt: null,
        );
        return;
      }

      final source = state;
      final session = await ref
          .read(imageSearchApiProvider)
          .createSession(
            fileBytes: source.fileBytes!,
            fileName: source.fileName!,
            mimeType: source.mimeType,
            movieIds: resolved.includeMovieIds,
            excludeMovieIds: resolved.excludeMovieIds,
            scoreThreshold: filter.scoreThreshold,
            target: filter.searchTarget,
          );
      if (!_isCurrentSearch(requestVersion)) {
        return;
      }
      _applySession(session, replaceItems: true);
    } catch (_) {
      if (_isCurrentSearch(requestVersion)) {
        state = state.copyWith(
          errorMessage: '以图搜图失败，请稍后重试',
          items: const <ImageSearchResultItemDto>[],
          sessionId: null,
          nextCursor: null,
          expiresAt: null,
        );
      }
    } finally {
      if (_isCurrentSearch(requestVersion)) {
        state = state.copyWith(
          isSearching: false,
          isResolvingActorMovieIds: false,
        );
      }
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.isLoadingMore ||
        current.isSearching ||
        current.sessionId == null ||
        !current.hasMore) {
      return;
    }

    final requestVersion = _searchVersion;
    final requestedSessionId = current.sessionId!;
    final requestedCursor = current.nextCursor!;
    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    try {
      final session = await ref
          .read(imageSearchApiProvider)
          .getNextResults(
            sessionId: requestedSessionId,
            cursor: requestedCursor,
            target: current.activeFilter.searchTarget,
          );
      if (!_isCurrentSearch(requestVersion) ||
          state.sessionId != requestedSessionId) {
        return;
      }
      _applySession(
        session,
        replaceItems: false,
        requestedCursor: requestedCursor,
      );
    } catch (_) {
      if (_isCurrentSearch(requestVersion) &&
          state.sessionId == requestedSessionId) {
        state = state.copyWith(errorMessage: '加载更多失败，请稍后重试');
      }
    } finally {
      if (_isCurrentSearch(requestVersion) &&
          state.sessionId == requestedSessionId) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  void _applySession(
    ImageSearchSessionDto session, {
    required bool replaceItems,
    String? requestedCursor,
  }) {
    final nextCursor = session.nextCursor;
    final normalizedNextCursor =
        nextCursor == requestedCursor ? null : nextCursor;
    final filteredItems = session.items
        .where(_matchesCurrentMovieFilter)
        .toList(growable: false);
    state = state.copyWith(
      sessionId: session.sessionId,
      nextCursor: normalizedNextCursor,
      expiresAt: session.expiresAt,
      items:
          replaceItems
              ? filteredItems
              : <ImageSearchResultItemDto>[...state.items, ...filteredItems],
    );
  }

  bool _matchesCurrentMovieFilter(ImageSearchResultItemDto item) {
    final currentMovieNumber = state.activeCurrentMovieNumber;
    if (currentMovieNumber == null || currentMovieNumber.isEmpty) {
      return true;
    }

    return switch (state.activeFilter.currentMovieScope) {
      ImageSearchCurrentMovieScope.all => true,
      ImageSearchCurrentMovieScope.onlyCurrent =>
        item.movieNumber == currentMovieNumber,
      ImageSearchCurrentMovieScope.excludeCurrent =>
        item.movieNumber != currentMovieNumber,
    };
  }

  String? _normalizeCurrentMovieNumber(String? movieNumber) {
    final normalized = movieNumber?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<_ResolvedMovieFilters?> _resolveMovieFilters(
    ImageSearchFilterState filter,
    int requestVersion,
  ) async {
    if (filter.actorFilterMode == ImageSearchActorFilterMode.none) {
      return const _ResolvedMovieFilters();
    }
    if (filter.selectedActors.isEmpty) {
      return null;
    }

    state = state.copyWith(isResolvingActorMovieIds: true);
    final movieIdGroups = await Future.wait(
      filter.selectedActors.map(
        (actor) =>
            ref.read(actorsApiProvider).getActorMovieIds(actorId: actor.id),
      ),
    );
    if (!_isCurrentSearch(requestVersion)) {
      return null;
    }
    final deduped = <int>{};
    for (final ids in movieIdGroups) {
      deduped.addAll(ids.where((id) => id > 0));
    }
    if (deduped.isEmpty) {
      return null;
    }

    final values = deduped.toList()..sort();
    return switch (filter.actorFilterMode) {
      ImageSearchActorFilterMode.none => const _ResolvedMovieFilters(),
      ImageSearchActorFilterMode.includeSelected => _ResolvedMovieFilters(
        includeMovieIds: values,
      ),
      ImageSearchActorFilterMode.excludeSelected => _ResolvedMovieFilters(
        excludeMovieIds: values,
      ),
    };
  }

  bool _isCurrentSearch(int requestVersion) =>
      !_isDisposed && requestVersion == _searchVersion;

  bool _isCurrentActorsRequest(int requestVersion) =>
      !_isDisposed && requestVersion == _actorsVersion;
}

class _ResolvedMovieFilters {
  const _ResolvedMovieFilters({
    this.includeMovieIds = const <int>[],
    this.excludeMovieIds = const <int>[],
  });

  final List<int> includeMovieIds;
  final List<int> excludeMovieIds;
}
