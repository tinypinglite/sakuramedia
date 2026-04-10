import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_session_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';

class ImageSearchController extends ChangeNotifier {
  ImageSearchController({
    required ImageSearchApi imageSearchApi,
    required ActorsApi actorsApi,
    this.loadMoreTriggerOffset = 300,
    ScrollController? scrollController,
  }) : _imageSearchApi = imageSearchApi,
       _actorsApi = actorsApi,
       scrollController = scrollController ?? ScrollController();

  final ImageSearchApi _imageSearchApi;
  final ActorsApi _actorsApi;
  final double loadMoreTriggerOffset;
  final ScrollController scrollController;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _mimeType;
  String? _sessionId;
  String? _nextCursor;
  DateTime? _expiresAt;
  List<ImageSearchResultItemDto> _items = const <ImageSearchResultItemDto>[];
  ImageSearchFilterState _activeFilter = const ImageSearchFilterState();
  String? _activeCurrentMovieNumber;
  List<ActorListItemDto> _subscribedActors = const <ActorListItemDto>[];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isLoadingSubscribedActors = false;
  bool _isResolvingActorMovieIds = false;
  bool _isPreviewExpanded = false;
  bool _isFilterExpanded = false;
  bool _scrollListenerAttached = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _subscribedActorsErrorMessage;

  Uint8List? get fileBytes => _fileBytes;
  String? get fileName => _fileName;
  String? get mimeType => _mimeType;
  String? get sessionId => _sessionId;
  String? get nextCursor => _nextCursor;
  DateTime? get expiresAt => _expiresAt;
  List<ImageSearchResultItemDto> get items => _items;
  List<ActorListItemDto> get subscribedActors => _subscribedActors;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingSubscribedActors => _isLoadingSubscribedActors;
  bool get isResolvingActorMovieIds => _isResolvingActorMovieIds;
  bool get isPreviewExpanded => _isPreviewExpanded;
  bool get isFilterExpanded => _isFilterExpanded;
  String? get errorMessage => _errorMessage;
  String? get subscribedActorsErrorMessage => _subscribedActorsErrorMessage;
  bool get hasMore => _nextCursor != null;
  bool get hasSource =>
      _fileBytes != null &&
      _fileBytes!.isNotEmpty &&
      (_fileName?.isNotEmpty ?? false);

  void setSource({
    required Uint8List fileBytes,
    required String fileName,
    String? mimeType,
  }) {
    _fileBytes = fileBytes;
    _fileName = fileName;
    _mimeType = mimeType;
    _sessionId = null;
    _nextCursor = null;
    _expiresAt = null;
    _items = const <ImageSearchResultItemDto>[];
    _isLoadingMore = false;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  void togglePreviewExpanded() {
    _isPreviewExpanded = !_isPreviewExpanded;
    _safeNotifyListeners();
  }

  void toggleFilterExpanded() {
    _isFilterExpanded = !_isFilterExpanded;
    _safeNotifyListeners();
  }

  void attachScrollListener() {
    if (_scrollListenerAttached) {
      return;
    }
    scrollController.addListener(_handleScroll);
    _scrollListenerAttached = true;
  }

  void detachScrollListener() {
    if (!_scrollListenerAttached) {
      return;
    }
    scrollController.removeListener(_handleScroll);
    _scrollListenerAttached = false;
  }

  Future<void> ensureSubscribedActorsLoaded() async {
    if (_isLoadingSubscribedActors || _subscribedActors.isNotEmpty) {
      return;
    }
    _isLoadingSubscribedActors = true;
    _subscribedActorsErrorMessage = null;
    _safeNotifyListeners();

    try {
      final actors = <ActorListItemDto>[];
      var page = 1;
      const pageSize = 200;
      while (true) {
        final response = await _actorsApi.getActors(
          subscriptionStatus: ActorSubscriptionStatus.subscribed,
          gender: ActorGender.female,
          page: page,
          pageSize: pageSize,
        );
        actors.addAll(response.items);
        if (actors.length >= response.total || response.items.isEmpty) {
          break;
        }
        page += 1;
      }
      _subscribedActors = actors;
    } catch (_) {
      _subscribedActorsErrorMessage = '加载已订阅女优失败';
    } finally {
      _isLoadingSubscribedActors = false;
      _safeNotifyListeners();
    }
  }

  Future<void> search({
    ImageSearchFilterState filter = const ImageSearchFilterState(),
    String? currentMovieNumber,
  }) async {
    if (!hasSource || _isSearching) {
      return;
    }

    _activeFilter = filter;
    _activeCurrentMovieNumber = _normalizeCurrentMovieNumber(
      currentMovieNumber,
    );
    _isSearching = true;
    _isLoadingMore = false;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final resolved = await _resolveMovieFilters(filter);
      if (resolved == null) {
        _errorMessage = '所选女优下没有可用于筛选的影片';
        _items = const <ImageSearchResultItemDto>[];
        _sessionId = null;
        _nextCursor = null;
        _expiresAt = null;
        return;
      }

      final session = await _imageSearchApi.createSession(
        fileBytes: _fileBytes!,
        fileName: _fileName!,
        mimeType: _mimeType,
        movieIds: resolved.includeMovieIds,
        excludeMovieIds: resolved.excludeMovieIds,
        scoreThreshold: filter.scoreThreshold,
      );
      _applySession(session, replaceItems: true);
    } catch (_) {
      _errorMessage = '以图搜图失败，请稍后重试';
      _items = const <ImageSearchResultItemDto>[];
      _sessionId = null;
      _nextCursor = null;
      _expiresAt = null;
    } finally {
      _isSearching = false;
      _isResolvingActorMovieIds = false;
      _safeNotifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isSearching || _sessionId == null || !hasMore) {
      return;
    }

    final requestedCursor = _nextCursor!;
    _isLoadingMore = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final session = await _imageSearchApi.getNextResults(
        sessionId: _sessionId!,
        cursor: requestedCursor,
      );
      _applySession(
        session,
        replaceItems: false,
        requestedCursor: requestedCursor,
      );
    } catch (_) {
      _errorMessage = '加载更多失败，请稍后重试';
    } finally {
      _isLoadingMore = false;
      _safeNotifyListeners();
    }
  }

  void _applySession(
    ImageSearchSessionDto session, {
    required bool replaceItems,
    String? requestedCursor,
  }) {
    _sessionId = session.sessionId;
    final nextCursor = session.nextCursor;
    _nextCursor = nextCursor == requestedCursor ? null : nextCursor;
    _expiresAt = session.expiresAt;
    final filteredItems = session.items
        .where(_matchesCurrentMovieFilter)
        .toList(growable: false);
    if (replaceItems) {
      final nextItems = <ImageSearchResultItemDto>[];
      for (final item in filteredItems) {
        nextItems.add(item);
      }
      _items = nextItems;
      return;
    }

    final nextItems = <ImageSearchResultItemDto>[];
    for (final item in _items) {
      nextItems.add(item);
    }
    for (final item in filteredItems) {
      nextItems.add(item);
    }
    _items = nextItems;
  }

  bool _matchesCurrentMovieFilter(ImageSearchResultItemDto item) {
    final currentMovieNumber = _activeCurrentMovieNumber;
    if (currentMovieNumber == null || currentMovieNumber.isEmpty) {
      return true;
    }

    return switch (_activeFilter.currentMovieScope) {
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
  ) async {
    if (filter.actorFilterMode == ImageSearchActorFilterMode.none) {
      return const _ResolvedMovieFilters();
    }
    if (filter.selectedActors.isEmpty) {
      return null;
    }

    _isResolvingActorMovieIds = true;
    _safeNotifyListeners();

    final movieIdGroups = await Future.wait(
      filter.selectedActors.map(
        (ActorListItemDto actor) =>
            _actorsApi.getActorMovieIds(actorId: actor.id),
      ),
    );
    final deduped = <int>{};
    for (final ids in movieIdGroups) {
      deduped.addAll(ids.where((int id) => id > 0));
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

  void _handleScroll() {
    if (!scrollController.hasClients ||
        _isSearching ||
        _isLoadingMore ||
        _errorMessage != null ||
        !hasMore) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - loadMoreTriggerOffset) {
      loadMore();
    }
  }

  void _safeNotifyListeners() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    detachScrollListener();
    scrollController.dispose();
    super.dispose();
  }
}

class _ResolvedMovieFilters {
  const _ResolvedMovieFilters({
    this.includeMovieIds = const <int>[],
    this.excludeMovieIds = const <int>[],
  });

  final List<int> includeMovieIds;
  final List<int> excludeMovieIds;
}
