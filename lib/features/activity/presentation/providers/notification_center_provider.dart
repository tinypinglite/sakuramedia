import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'notification_center_provider.g.dart';

/// 全局常驻通知中心，登录后通过通知列表快照轮询。
@Riverpod(keepAlive: true)
class NotificationCenter extends _$NotificationCenter {
  static const int _pageSize = 20;
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const Duration _readDebounceDelay = Duration(milliseconds: 400);

  SessionStore? _sessionStore;
  bool _lastHasSession = false;
  Timer? _pollTimer;
  Timer? _readDebounce;
  int _nextPage = 1;
  late final DebouncedLatestRequest _filterRequests = DebouncedLatestRequest();
  int _lifecycleGeneration = 0;
  int _notificationFilterGeneration = 0;
  final Set<int> _pendingReadIds = <int>{};
  final Set<int> _inFlightReadIds = <int>{};

  @override
  NotificationCenterState build() {
    final sessionStore = ref.watch(sessionStoreProvider);
    _sessionStore = sessionStore;
    _lastHasSession = sessionStore.hasSession;
    sessionStore.addListener(_handleSessionChanged);
    ref.onDispose(() {
      sessionStore.removeListener(_handleSessionChanged);
      _pollTimer?.cancel();
      _readDebounce?.cancel();
      _filterRequests.dispose();
    });
    if (_lastHasSession) scheduleMicrotask(initialize);
    return NotificationCenterState.initial;
  }

  void _handleSessionChanged() {
    if (!ref.mounted) return;
    final hasSession = _sessionStore?.hasSession ?? false;
    if (hasSession == _lastHasSession) return;
    _lastHasSession = hasSession;
    if (hasSession) {
      unawaited(initialize());
    } else {
      _teardown();
    }
  }

  Future<void> initialize() async {
    if (!ref.mounted || state.initialized || state.isInitialLoading) return;
    await reloadAll();
  }

  Future<void> reloadAll() async {
    final generation = ++_lifecycleGeneration;
    _pollTimer?.cancel();
    _filterRequests.cancel();
    _notificationFilterGeneration++;
    state = state.copyWith(
      isInitialLoading: true,
      initialErrorMessage: null,
      refreshErrorMessage: null,
      filterUpdate: const FilterUpdateState.idle(),
      connectionState: NotificationConnectionState.connecting,
      connectionMessage: '正在同步通知',
    );
    try {
      final bootstrap = await _loadBootstrapState();
      if (!ref.mounted || generation != _lifecycleGeneration) return;
      _applyBootstrapState(bootstrap);
      state = state.copyWith(
        initialized: true,
        isInitialLoading: false,
        initialErrorMessage: null,
        connectionState: NotificationConnectionState.polling,
        connectionMessage: '每 30 秒同步通知',
      );
      _startPolling(generation);
    } catch (error) {
      if (!ref.mounted || generation != _lifecycleGeneration) return;
      state = state.copyWith(
        isInitialLoading: false,
        initialErrorMessage: apiErrorMessage(error, fallback: '通知加载失败，请稍后重试'),
        connectionState: NotificationConnectionState.polling,
        connectionMessage: '通知同步失败，可手动刷新',
      );
      _startPolling(generation);
    }
  }

  void _startPolling(int generation) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) {
      if (generation == _lifecycleGeneration) unawaited(_refreshFromPolling());
    });
  }

  Future<void> applyNotificationFilter(ActivityNotificationFilterState next) {
    if (state.filter == next) return Future<void>.value();
    _notificationFilterGeneration++;
    state = state.copyWith(
      filter: next,
      filterUpdate: const FilterUpdateState.waiting(),
      isRefreshing: true,
      isLoadingMore: false,
      refreshErrorMessage: null,
      loadMoreErrorMessage: null,
    );
    return _filterRequests.schedule(_refreshNotifications);
  }

  Future<void> refreshNotifications() {
    _notificationFilterGeneration++;
    state = state.copyWith(
      isRefreshing: true,
      isLoadingMore: false,
      filterUpdate: const FilterUpdateState.loading(),
      refreshErrorMessage: null,
      loadMoreErrorMessage: null,
    );
    return _filterRequests.runNow(_refreshNotifications);
  }

  Future<void> _refreshNotifications(int requestId) async {
    if (!ref.mounted || !_filterRequests.isCurrent(requestId)) return;
    final filter = state.filter;
    state = state.copyWith(filterUpdate: const FilterUpdateState.loading());
    try {
      final response = await ref
          .read(activityApiProvider)
          .getNotifications(
            page: 1,
            pageSize: _pageSize,
            category: filter.category,
          );
      if (!ref.mounted || !_filterRequests.isCurrent(requestId)) return;
      final notifications = _sortNotifications(response.items);
      _nextPage = response.page + 1;
      state = state.copyWith(
        notifications: notifications,
        hasMore: notifications.length < response.total,
        loadMoreErrorMessage: null,
        refreshErrorMessage: null,
        filterUpdate: const FilterUpdateState.idle(),
      );
    } catch (error) {
      if (!ref.mounted || !_filterRequests.isCurrent(requestId)) return;
      final message = apiErrorMessage(error, fallback: '通知筛选刷新失败，请重试');
      state = state.copyWith(
        refreshErrorMessage: message,
        filterUpdate: FilterUpdateState.failed(message),
      );
    } finally {
      if (ref.mounted && _filterRequests.isCurrent(requestId)) {
        state = state.copyWith(isRefreshing: false);
      }
    }
  }

  Future<void> loadMoreNotifications() async {
    if (state.isLoadingMore ||
        state.isRefreshing ||
        !state.filterUpdate.isIdle ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, loadMoreErrorMessage: null);
    final generation = _notificationFilterGeneration;
    try {
      final response = await ref
          .read(activityApiProvider)
          .getNotifications(
            page: _nextPage,
            pageSize: _pageSize,
            category: state.filter.category,
          );
      if (!ref.mounted || generation != _notificationFilterGeneration) return;
      final ids = state.notifications.map((item) => item.id).toSet();
      final notifications = <ActivityNotificationDto>[
        ...state.notifications,
        ...response.items.where((item) => ids.add(item.id)),
      ];
      _nextPage = response.page + 1;
      state = state.copyWith(
        notifications: notifications,
        hasMore: notifications.length < response.total,
        loadMoreErrorMessage: null,
      );
    } catch (error) {
      if (ref.mounted && generation == _notificationFilterGeneration) {
        state = state.copyWith(
          loadMoreErrorMessage: apiErrorMessage(
            error,
            fallback: '加载更多通知失败，请点击重试',
          ),
        );
      }
    } finally {
      if (ref.mounted && generation == _notificationFilterGeneration) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  void onNotificationDisplayed(int id) {
    final item = _findNotification(state.notifications, id);
    if (item == null ||
        item.isRead ||
        _inFlightReadIds.contains(id) ||
        _pendingReadIds.contains(id)) {
      return;
    }
    _pendingReadIds.add(id);
    _readDebounce?.cancel();
    _readDebounce = Timer(_readDebounceDelay, _flushPendingReads);
  }

  Future<void> _flushPendingReads() async {
    if (!ref.mounted || _pendingReadIds.isEmpty) return;
    final ids = _pendingReadIds.toList(growable: false);
    _pendingReadIds.clear();
    _inFlightReadIds.addAll(ids);
    state = state.copyWith(
      notifications: _setLocalRead(state.notifications, ids, isRead: true),
    );
    try {
      final result = await ref
          .read(activityApiProvider)
          .markNotificationsRead(ids);
      if (ref.mounted) state = state.copyWith(unreadCount: result.unreadCount);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          notifications: _setLocalRead(state.notifications, ids, isRead: false),
        );
      }
    } finally {
      _inFlightReadIds.removeAll(ids);
    }
  }

  Future<void> markAllRead() async {
    if (!ref.mounted || state.isMarkingAllRead) return;
    _readDebounce?.cancel();
    _pendingReadIds.clear();
    final previous = state.notifications;
    final unread = state.unreadCount;
    state = state.copyWith(
      isMarkingAllRead: true,
      notifications: <ActivityNotificationDto>[
        for (final item in state.notifications)
          item.isRead ? item : item.copyWith(isRead: true),
      ],
      unreadCount: 0,
    );
    try {
      final result = await ref
          .read(activityApiProvider)
          .markAllNotificationsRead();
      if (ref.mounted) state = state.copyWith(unreadCount: result.unreadCount);
    } catch (_) {
      if (ref.mounted)
        state = state.copyWith(notifications: previous, unreadCount: unread);
    } finally {
      if (ref.mounted) state = state.copyWith(isMarkingAllRead: false);
    }
  }

  Future<void> _refreshFromPolling() async {
    try {
      final filter = state.filter;
      final api = ref.read(activityApiProvider);
      final notificationsFuture = api.getNotifications(
        page: 1,
        pageSize: _pageSize,
        category: filter.category,
      );
      final unreadFuture = api.getNotifications(
        page: 1,
        pageSize: 1,
        isRead: false,
      );
      final notifications = await notificationsFuture;
      final unread = await unreadFuture;
      if (!ref.mounted) return;
      if (state.filter == filter && state.filterUpdate.isIdle) {
        final items = _sortNotifications(notifications.items);
        _nextPage = notifications.page + 1;
        state = state.copyWith(
          notifications: items,
          hasMore: items.length < notifications.total,
          loadMoreErrorMessage: null,
          refreshErrorMessage: null,
        );
      }
      state = state.copyWith(
        unreadCount: unread.total,
        connectionState: NotificationConnectionState.polling,
        connectionMessage: '每 30 秒同步通知',
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          connectionState: NotificationConnectionState.polling,
          connectionMessage: '通知同步失败，可手动刷新',
        );
      }
    }
  }

  void _teardown() {
    _lifecycleGeneration++;
    _notificationFilterGeneration++;
    _pollTimer?.cancel();
    _filterRequests.cancel();
    _readDebounce?.cancel();
    _pendingReadIds.clear();
    _inFlightReadIds.clear();
    _nextPage = 1;
    state = NotificationCenterState.initial;
  }

  Future<ActivityBootstrapDto> _loadBootstrapState() => ref
      .read(activityApiProvider)
      .getBootstrap(notificationCategory: state.filter.category);

  void _applyBootstrapState(ActivityBootstrapDto response) {
    final notifications = _sortNotifications(response.notifications.items);
    _nextPage = response.notifications.page + 1;
    state = state.copyWith(
      notifications: notifications,
      unreadCount: response.unreadCount,
      hasMore: notifications.length < response.notifications.total,
      loadMoreErrorMessage: null,
      refreshErrorMessage: null,
    );
  }

  List<ActivityNotificationDto> _setLocalRead(
    List<ActivityNotificationDto> source,
    Iterable<int> ids, {
    required bool isRead,
  }) {
    final idSet = ids.toSet();
    return [
      for (final item in source)
        idSet.contains(item.id) && item.isRead != isRead
            ? item.copyWith(isRead: isRead)
            : item,
    ];
  }

  ActivityNotificationDto? _findNotification(
    List<ActivityNotificationDto> source,
    int id,
  ) {
    for (final item in source) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<ActivityNotificationDto> _sortNotifications(
    List<ActivityNotificationDto> items,
  ) {
    final sorted = List<ActivityNotificationDto>.from(items);
    sorted.sort((left, right) {
      final leftAt = left.createdAt?.millisecondsSinceEpoch ?? 0;
      final rightAt = right.createdAt?.millisecondsSinceEpoch ?? 0;
      return rightAt.compareTo(leftAt);
    });
    return sorted;
  }
}
