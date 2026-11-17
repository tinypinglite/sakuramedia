import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_session_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_api_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

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

  void initialize(
    ImageSearchCurrentMovieScope initialCurrentMovieScope, {
    ImageSearchInputKind initialInputKind = ImageSearchInputKind.image,
  }) {
    if (state.hasInitialized) {
      return;
    }
    state = state.copyWith(
      filterState: state.filterState.copyWith(
        currentMovieScope: initialCurrentMovieScope,
      ),
      inputKind: initialInputKind,
      hasInitialized: true,
    );
  }

  void selectInputKind(ImageSearchInputKind inputKind) {
    if (state.inputKind == inputKind) {
      return;
    }
    _searchVersion += 1;
    state = state.copyWith(
      fileBytes: null,
      fileName: null,
      mimeType: null,
      inputKind: inputKind,
      textQuery: null,
      sessionId: null,
      nextCursor: null,
      expiresAt: null,
      items: const <ImageSearchResultItemDto>[],
      isSearching: false,
      isLoadingMore: false,
      isResolvingActorMovieIds: false,
      isLoadMoreFailed: false,
      errorMessage: null,
      bootstrappedSourceSignature: null,
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
      inputKind: ImageSearchInputKind.image,
      textQuery: null,
      sessionId: null,
      nextCursor: null,
      expiresAt: null,
      items: const <ImageSearchResultItemDto>[],
      isSearching: false,
      isLoadingMore: false,
      isResolvingActorMovieIds: false,
      isLoadMoreFailed: false,
      errorMessage: null,
      bootstrappedSourceSignature: bootstrappedSourceSignature,
    );
  }

  void setTextSource(String text) {
    _searchVersion += 1;
    state = state.copyWith(
      fileBytes: null,
      fileName: null,
      mimeType: null,
      inputKind: ImageSearchInputKind.text,
      textQuery: text.trim(),
      sessionId: null,
      nextCursor: null,
      expiresAt: null,
      items: const <ImageSearchResultItemDto>[],
      isSearching: false,
      isLoadingMore: false,
      isResolvingActorMovieIds: false,
      isLoadMoreFailed: false,
      errorMessage: null,
      bootstrappedSourceSignature: null,
    );
  }

  void togglePreviewExpanded() {
    state = state.copyWith(isPreviewExpanded: !state.isPreviewExpanded);
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
        state = state.copyWith(
          subscribedActorsErrorMessage: ref
              .read(appLocalizationsProvider)
              .imageSearchSubscribedActorsLoadFailed,
        );
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
      isLoadMoreFailed: false,
      errorMessage: null,
    );

    try {
      final resolved = await _resolveMovieFilters(filter, requestVersion);
      if (!_isCurrentSearch(requestVersion)) {
        return;
      }
      if (resolved == null) {
        state = state.copyWith(
          errorMessage: ref
              .read(appLocalizationsProvider)
              .imageSearchNoMoviesForActors,
          items: const <ImageSearchResultItemDto>[],
          sessionId: null,
          nextCursor: null,
          expiresAt: null,
        );
        return;
      }

      final source = state;
      final api = ref.read(imageSearchApiProvider);
      final session = source.inputKind == ImageSearchInputKind.image
          ? await api.createSession(
              fileBytes: source.fileBytes!,
              fileName: source.fileName!,
              mimeType: source.mimeType,
              movieIds: resolved.includeMovieIds,
              excludeMovieIds: resolved.excludeMovieIds,
              scoreThreshold: filter.scoreThreshold,
              target: filter.searchTarget,
            )
          : await api.createTextSession(
              text: source.textQuery!,
              movieIds: resolved.includeMovieIds,
              excludeMovieIds: resolved.excludeMovieIds,
              scoreThreshold: filter.scoreThreshold,
              target: filter.searchTarget,
            );
      if (!_isCurrentSearch(requestVersion)) {
        return;
      }
      _applySession(session, replaceItems: true);
    } catch (error) {
      if (_isCurrentSearch(requestVersion)) {
        final l10n = ref.read(appLocalizationsProvider);
        state = state.copyWith(
          errorMessage:
              _imageSearchRebuildRequiredMessage(error, l10n) ??
              (state.inputKind == ImageSearchInputKind.image
                  ? l10n.imageSearchImageSearchFailed
                  : l10n.imageSearchTextSearchFailed),
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
    state = state.copyWith(
      isLoadingMore: true,
      isLoadMoreFailed: false,
      errorMessage: null,
    );

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
    } catch (error) {
      if (_isCurrentSearch(requestVersion) &&
          state.sessionId == requestedSessionId) {
        final l10n = ref.read(appLocalizationsProvider);
        final rebuildRequiredMessage = _imageSearchRebuildRequiredMessage(
          error,
          l10n,
        );
        state = state.copyWith(
          errorMessage:
              rebuildRequiredMessage ?? l10n.imageSearchLoadMoreFailed,
          isLoadMoreFailed: rebuildRequiredMessage == null,
          nextCursor: rebuildRequiredMessage == null ? state.nextCursor : null,
        );
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
    final normalizedNextCursor = nextCursor == requestedCursor
        ? null
        : nextCursor;
    final filteredItems = session.items
        .where(_matchesCurrentMovieFilter)
        .toList(growable: false);
    state = state.copyWith(
      sessionId: session.sessionId,
      nextCursor: normalizedNextCursor,
      expiresAt: session.expiresAt,
      items: replaceItems
          ? filteredItems
          : <ImageSearchResultItemDto>[...state.items, ...filteredItems],
    );
  }

  String? _imageSearchRebuildRequiredMessage(
    Object error,
    AppLocalizations l10n,
  ) {
    if (error is ApiException &&
        error.error?.code == 'image_search_index_rebuild_required') {
      return l10n.imageSearchIndexRebuildRequired;
    }
    return null;
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
