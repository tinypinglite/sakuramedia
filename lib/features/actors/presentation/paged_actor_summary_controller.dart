import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';

typedef ActorSummaryPageFetcher =
    Future<PaginatedResponseDto<ActorListItemDto>> Function(
      int page,
      int pageSize,
    );

typedef ActorSubscriptionWriter = Future<void> Function({required int actorId});

enum ActorSubscriptionToggleStatus { subscribed, unsubscribed, failed, ignored }

class ActorSubscriptionToggleResult {
  const ActorSubscriptionToggleResult({required this.status, this.message});

  const ActorSubscriptionToggleResult.subscribed()
    : this(status: ActorSubscriptionToggleStatus.subscribed);

  const ActorSubscriptionToggleResult.unsubscribed()
    : this(status: ActorSubscriptionToggleStatus.unsubscribed);

  const ActorSubscriptionToggleResult.failed({required String message})
    : this(status: ActorSubscriptionToggleStatus.failed, message: message);

  const ActorSubscriptionToggleResult.ignored()
    : this(status: ActorSubscriptionToggleStatus.ignored);

  final ActorSubscriptionToggleStatus status;
  final String? message;
}

class PagedActorSummaryController extends ChangeNotifier {
  PagedActorSummaryController({
    required this.fetchPage,
    required this.subscribeActor,
    required this.unsubscribeActor,
    this.initialPage = 1,
    this.pageSize = 24,
    this.loadMoreTriggerOffset = 300,
    ScrollController? scrollController,
  }) : scrollController = scrollController ?? ScrollController(),
       _currentPage = initialPage - 1;

  final ActorSummaryPageFetcher fetchPage;
  final ActorSubscriptionWriter subscribeActor;
  final ActorSubscriptionWriter unsubscribeActor;
  final int initialPage;
  final int pageSize;
  final double loadMoreTriggerOffset;
  final ScrollController scrollController;

  final List<ActorListItemDto> _items = <ActorListItemDto>[];
  final Set<int> _updatingActorIds = <int>{};

  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoadedOnce = false;
  bool _hasMore = true;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _scrollListenerAttached = false;
  String? _initialErrorMessage;
  String? _loadMoreErrorMessage;
  int _currentPage;
  int _total = 0;

  List<ActorListItemDto> get items =>
      UnmodifiableListView<ActorListItemDto>(_items);
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedOnce => _hasLoadedOnce;
  bool get hasMore => _hasMore;
  String? get initialErrorMessage => _initialErrorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  int get currentPage => _currentPage;
  int get total => _total;

  bool isSubscriptionUpdating(int actorId) {
    return _updatingActorIds.contains(actorId);
  }

  Future<ActorSubscriptionToggleResult> toggleSubscription({
    required int actorId,
  }) async {
    final index = _items.indexWhere((item) => item.id == actorId);
    if (index == -1 || _updatingActorIds.contains(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }

    final actor = _items[index];
    _updatingActorIds.add(actorId);
    _safeNotifyListeners();

    try {
      if (actor.isSubscribed) {
        await unsubscribeActor(actorId: actorId);
        _items[index] = actor.copyWith(isSubscribed: false);
        return const ActorSubscriptionToggleResult.unsubscribed();
      }

      await subscribeActor(actorId: actorId);
      _items[index] = actor.copyWith(isSubscribed: true);
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
      _safeNotifyListeners();
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    await _loadPage(reset: true);
  }

  Future<void> reload() async {
    _isInitialized = true;
    await _loadPage(reset: true);
  }

  Future<void> refresh() async {
    if (_isInitialLoading || _isLoadingMore) {
      return;
    }
    final response = await fetchPage(initialPage, pageSize);
    if (_isDisposed) {
      return;
    }
    _items
      ..clear()
      ..addAll(response.items);
    _currentPage = response.page;
    _total = response.total;
    _hasMore = _items.length < _total;
    _hasLoadedOnce = true;
    _initialErrorMessage = null;
    _loadMoreErrorMessage = null;
    _safeNotifyListeners();
  }

  Future<void> loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    await _loadPage(reset: false);
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

  Future<void> _loadPage({required bool reset}) async {
    final nextPage = reset ? initialPage : _currentPage + 1;

    if (reset) {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _initialErrorMessage = null;
      _loadMoreErrorMessage = null;
      _currentPage = initialPage - 1;
      _total = 0;
      _hasMore = true;
      _hasLoadedOnce = false;
      _items.clear();
      _safeNotifyListeners();
    } else {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
      _safeNotifyListeners();
    }

    try {
      final response = await fetchPage(nextPage, pageSize);
      if (_isDisposed) {
        return;
      }

      if (reset) {
        _items
          ..clear()
          ..addAll(response.items);
      } else {
        _items.addAll(response.items);
      }

      _currentPage = response.page;
      _total = response.total;
      _hasLoadedOnce = true;
      _hasMore = _items.length < _total;
      _initialErrorMessage = null;
      _loadMoreErrorMessage = null;
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      if (reset) {
        _initialErrorMessage = '女优列表加载失败，请稍后重试';
        _hasMore = false;
      } else {
        _loadMoreErrorMessage = '加载更多失败，请点击重试';
        _hasMore = _items.length < _total;
      }
    } finally {
      if (!_isDisposed) {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _safeNotifyListeners();
      }
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasMore) {
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
