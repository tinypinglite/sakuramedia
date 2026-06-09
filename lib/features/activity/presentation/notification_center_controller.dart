import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';

enum NotificationConnectionState { connecting, live, reconnecting, polling }

/// 全局常驻的通知中心状态：分页通知列表、未读角标、实时事件流与「无感自动已读」。
///
/// 与 [SessionStore] 绑定——登录后才拉取 bootstrap 并连 SSE，登出时断流清空，
/// 因此可在侧边栏角标等任意位置长期订阅。SSE 走统一的 `/system/events/stream`
/// 端点，本控制器只关心通知相关事件（创建/更新 + `notifications_read`
/// / `notifications_read_all` 两类聚合事件）。
class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController({required ActivityApi activityApi})
    : _activityApi = activityApi;

  static const int _pageSize = 20;
  static const Duration _longDisconnectThreshold = Duration(minutes: 2);
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const Duration _readDebounceDelay = Duration(milliseconds: 400);
  static const List<Duration> _reconnectDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  final ActivityApi _activityApi;

  SessionStore? _boundSessionStore;
  bool _lastHasSession = false;

  NotificationConnectionState _connectionState =
      NotificationConnectionState.connecting;
  String? _connectionMessage;
  bool _initialized = false;
  bool _isInitialLoading = false;
  String? _initialErrorMessage;
  int _unreadCount = 0;
  int _lastEventId = 0;
  int _nextPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  String? _loadMoreErrorMessage;
  String? _refreshErrorMessage;
  ActivityNotificationFilterState _filter =
      ActivityNotificationFilterState.initial;
  List<ActivityNotificationDto> _notifications =
      const <ActivityNotificationDto>[];

  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  StreamSubscription<ActivityStreamEvent>? _eventSubscription;
  DateTime? _disconnectStartedAt;
  int _reconnectAttempt = 0;
  int _refreshRequestId = 0;
  final List<ActivityStreamEvent> _pendingStreamEvents =
      <ActivityStreamEvent>[];
  bool _isStreamFlushScheduled = false;

  // 「无感自动已读」批处理：渲染到的未读项进 _pendingReadIds，去抖后批量上报。
  final Set<int> _pendingReadIds = <int>{};
  final Set<int> _inFlightReadIds = <int>{};
  Timer? _readDebounce;
  bool _isMarkingAllRead = false;

  bool _disposed = false;

  bool get initialized => _initialized;
  bool get isInitialLoading => _isInitialLoading;
  String? get initialErrorMessage => _initialErrorMessage;
  int get unreadCount => _unreadCount;
  NotificationConnectionState get connectionState => _connectionState;
  String? get connectionMessage => _connectionMessage;
  ActivityNotificationFilterState get filter => _filter;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  String? get refreshErrorMessage => _refreshErrorMessage;
  bool get isMarkingAllRead => _isMarkingAllRead;
  bool get isPollingFallback =>
      _connectionState == NotificationConnectionState.polling;
  UnmodifiableListView<ActivityNotificationDto> get notifications =>
      UnmodifiableListView<ActivityNotificationDto>(_notifications);

  /// 绑定会话：登录后拉取并连流，登出时断开清空。仿 AppPageStateCache 的范式。
  void bindSessionStore(SessionStore sessionStore) {
    if (identical(_boundSessionStore, sessionStore)) {
      return;
    }
    _boundSessionStore?.removeListener(_handleSessionChanged);
    _boundSessionStore = sessionStore;
    _lastHasSession = sessionStore.hasSession;
    _boundSessionStore?.addListener(_handleSessionChanged);
    if (_lastHasSession) {
      unawaited(initialize());
    } else {
      _teardown();
    }
  }

  void _handleSessionChanged() {
    final sessionStore = _boundSessionStore;
    if (sessionStore == null || _disposed) {
      return;
    }
    final hasSession = sessionStore.hasSession;
    if (hasSession == _lastHasSession) {
      return;
    }
    _lastHasSession = hasSession;
    if (hasSession) {
      unawaited(initialize());
    } else {
      _teardown();
    }
  }

  Future<void> initialize() async {
    if (_disposed || _initialized || _isInitialLoading) {
      return;
    }
    await reloadAll();
  }

  Future<void> reloadAll() async {
    _refreshRequestId += 1;
    _cancelReconnectTimer();
    _cancelPollingTimer();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _resetPendingStreamEvents();

    _isInitialLoading = true;
    _initialErrorMessage = null;
    _refreshErrorMessage = null;
    _connectionState = NotificationConnectionState.connecting;
    _connectionMessage = '正在同步通知';
    _notifySafely();

    try {
      await _loadBootstrapState();
      if (_disposed) {
        return;
      }
      _initialized = true;
      _isInitialLoading = false;
      _initialErrorMessage = null;
      _notifySafely();
      await _connectStream();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _isInitialLoading = false;
      _initialErrorMessage = '通知加载失败，请稍后重试';
      _connectionState = NotificationConnectionState.reconnecting;
      _connectionMessage = null;
      _notifySafely();
    }
  }

  Future<void> applyNotificationFilter(
    ActivityNotificationFilterState next,
  ) async {
    if (_filter == next) {
      return;
    }
    _filter = next;
    await refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    final requestId = ++_refreshRequestId;
    _isRefreshing = true;
    _refreshErrorMessage = null;
    _loadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getNotifications(
        page: 1,
        pageSize: _pageSize,
        category: _filter.category,
      );
      if (_disposed || requestId != _refreshRequestId) {
        return;
      }
      _notifications = _sortNotifications(response.items);
      _nextPage = response.page + 1;
      _hasMore = _notifications.length < response.total;
      _loadMoreErrorMessage = null;
      _refreshErrorMessage = null;
    } catch (_) {
      if (_disposed || requestId != _refreshRequestId) {
        return;
      }
      _refreshErrorMessage = '通知筛选刷新失败，请重试';
    } finally {
      if (!_disposed && requestId == _refreshRequestId) {
        _isRefreshing = false;
        _notifySafely();
      }
    }
  }

  Future<void> loadMoreNotifications() async {
    if (_isLoadingMore || _isRefreshing || !_hasMore) {
      return;
    }
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getNotifications(
        page: _nextPage,
        pageSize: _pageSize,
        category: _filter.category,
      );
      if (_disposed) {
        return;
      }
      _notifications = <ActivityNotificationDto>[
        ..._notifications,
        ...response.items.where(
          (item) => !_notifications.any((it) => it.id == item.id),
        ),
      ];
      _nextPage = response.page + 1;
      _hasMore = _notifications.length < response.total;
      _loadMoreErrorMessage = null;
    } catch (_) {
      if (_disposed) {
        return;
      }
      _loadMoreErrorMessage = '加载更多通知失败，请点击重试';
    } finally {
      if (!_disposed) {
        _isLoadingMore = false;
        _notifySafely();
      }
    }
  }

  /// UI 在通知卡片被渲染（展示）时调用：未读项进入待已读队列，去抖后批量上报。
  void onNotificationDisplayed(int id) {
    if (_disposed) {
      return;
    }
    final current = _findNotification(id);
    if (current == null || current.isRead) {
      return;
    }
    if (_inFlightReadIds.contains(id) || _pendingReadIds.contains(id)) {
      return;
    }
    _pendingReadIds.add(id);
    _readDebounce?.cancel();
    _readDebounce = Timer(_readDebounceDelay, _flushPendingReads);
  }

  Future<void> _flushPendingReads() async {
    if (_disposed || _pendingReadIds.isEmpty) {
      return;
    }
    final batch = _pendingReadIds.toList(growable: false);
    _pendingReadIds.clear();
    _inFlightReadIds.addAll(batch);

    // 乐观：本地先置已读（避免重复上报 + 视觉即时），未读数以服务端返回为准。
    for (final id in batch) {
      _setLocalRead(id, isRead: true);
    }
    _notifySafely();

    try {
      final result = await _activityApi.markNotificationsRead(batch);
      if (_disposed) {
        return;
      }
      _unreadCount = result.unreadCount;
      _notifySafely();
    } catch (_) {
      if (_disposed) {
        return;
      }
      // 失败回滚为未读，下次该项再次进入视口会重试。
      for (final id in batch) {
        _setLocalRead(id, isRead: false);
      }
      _notifySafely();
    } finally {
      _inFlightReadIds.removeAll(batch);
    }
  }

  /// 一键全部已读：调用 `POST /system/notifications/read-all`，本地全部置已读，
  /// 用返回的 `unread_count` 校正角标；失败回滚到调用前快照。
  Future<void> markAllRead() async {
    if (_disposed || _isMarkingAllRead) {
      return;
    }
    _isMarkingAllRead = true;
    // 取消待上报的自动已读，避免与 read-all 重复请求。
    _readDebounce?.cancel();
    _pendingReadIds.clear();

    final previousNotifications = _notifications;
    final previousUnread = _unreadCount;
    _notifications = <ActivityNotificationDto>[
      for (final item in _notifications)
        item.isRead ? item : item.copyWith(isRead: true),
    ];
    _unreadCount = 0;
    _notifySafely();

    try {
      final result = await _activityApi.markAllNotificationsRead();
      if (_disposed) {
        return;
      }
      _unreadCount = result.unreadCount;
    } catch (_) {
      if (_disposed) {
        return;
      }
      _notifications = previousNotifications;
      _unreadCount = previousUnread;
    } finally {
      if (!_disposed) {
        _isMarkingAllRead = false;
        _notifySafely();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _boundSessionStore?.removeListener(_handleSessionChanged);
    _readDebounce?.cancel();
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _eventSubscription?.cancel();
    _resetPendingStreamEvents();
    super.dispose();
  }

  void _teardown() {
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _readDebounce?.cancel();
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _resetPendingStreamEvents();
    _pendingReadIds.clear();
    _inFlightReadIds.clear();
    _notifications = const <ActivityNotificationDto>[];
    _unreadCount = 0;
    _lastEventId = 0;
    _nextPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
    _isRefreshing = false;
    _loadMoreErrorMessage = null;
    _refreshErrorMessage = null;
    _initialErrorMessage = null;
    _isInitialLoading = false;
    _initialized = false;
    _filter = ActivityNotificationFilterState.initial;
    _connectionState = NotificationConnectionState.connecting;
    _connectionMessage = null;
    _disconnectStartedAt = null;
    _reconnectAttempt = 0;
    _notifySafely();
  }

  Future<void> _loadBootstrapState() async {
    final response = await _activityApi.getBootstrap(
      notificationCategory: _filter.category,
    );
    _applyBootstrapState(response);
  }

  void _applyBootstrapState(ActivityBootstrapDto response) {
    _notifications = _sortNotifications(response.notifications.items);
    _unreadCount = response.unreadCount;
    _nextPage = response.notifications.page + 1;
    _hasMore = _notifications.length < response.notifications.total;
    _loadMoreErrorMessage = null;
    _refreshErrorMessage = null;
    _lastEventId = response.latestEventId;
  }

  Future<void> _connectStream() async {
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _connectionState = NotificationConnectionState.connecting;
    _connectionMessage = '正在连接实时通知';
    _notifySafely();

    if (_disconnectStartedAt != null &&
        DateTime.now().difference(_disconnectStartedAt!) >
            _longDisconnectThreshold) {
      try {
        await _loadBootstrapState();
        _notifySafely();
      } catch (_) {
        // 长断线恢复失败时忽略，继续尝试连流。
      }
    }

    final stream = _activityApi.streamEvents(afterEventId: _lastEventId);
    _eventSubscription = stream.listen(
      _handleStreamEvent,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
      cancelOnError: false,
    );
    _connectionState = NotificationConnectionState.live;
    _connectionMessage = '实时连接中';
    _reconnectAttempt = 0;
    _disconnectStartedAt = null;
    _notifySafely();
  }

  void _handleStreamEvent(ActivityStreamEvent event) {
    if (event.id != null && event.id! > _lastEventId) {
      _lastEventId = event.id!;
    }
    _pendingStreamEvents.add(event);
    if (_isStreamFlushScheduled) {
      return;
    }
    _isStreamFlushScheduled = true;
    scheduleMicrotask(_flushPendingStreamEvents);
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    if (error is ActivityEventStreamUnsupportedException) {
      _startPollingFallback();
      return;
    }
    _scheduleReconnect();
  }

  void _handleStreamDone() {
    if (_disposed || isPollingFallback) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || isPollingFallback) {
      return;
    }
    _disconnectStartedAt ??= DateTime.now();
    _connectionState = NotificationConnectionState.reconnecting;
    _connectionMessage = '实时连接已断开，正在重连';
    _notifySafely();

    final delay =
        _reconnectDelays[_reconnectAttempt.clamp(
          0,
          _reconnectDelays.length - 1,
        )];
    _reconnectAttempt += 1;
    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () async {
      if (_disposed) {
        return;
      }
      try {
        await _eventSubscription?.cancel();
        await _connectStream();
      } catch (error) {
        if (error is ActivityEventStreamUnsupportedException) {
          _startPollingFallback();
          return;
        }
        _scheduleReconnect();
      }
    });
  }

  void _startPollingFallback() {
    _resetPendingStreamEvents();
    _cancelReconnectTimer();
    _connectionState = NotificationConnectionState.polling;
    _connectionMessage = '当前浏览器不支持实时连接，已切换为 30 秒轮询';
    _notifySafely();
    _cancelPollingTimer();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (_disposed) {
        return;
      }
      try {
        await _loadBootstrapState();
        _notifySafely();
      } catch (_) {
        // 保留最近一次成功状态，轮询失败时不清空页面。
      }
    });
  }

  // 批量合并一批 SSE，避免一条事件触发一次整页重建。
  void _flushPendingStreamEvents() {
    _isStreamFlushScheduled = false;
    if (_disposed || _pendingStreamEvents.isEmpty) {
      return;
    }

    final events = List<ActivityStreamEvent>.from(_pendingStreamEvents);
    _pendingStreamEvents.clear();

    var hasChanges = false;
    for (final event in events) {
      if (event.isHeartbeat) {
        const liveMessage = '实时连接中';
        final hasStateChanged =
            _connectionState != NotificationConnectionState.live ||
            _connectionMessage != liveMessage;
        _connectionState = NotificationConnectionState.live;
        _connectionMessage = liveMessage;
        hasChanges = hasChanges || hasStateChanged;
        continue;
      }

      if (event.isNotificationCreated && event.notification != null) {
        _applyNotificationSnapshot(
          event.notification!,
          insertAtFrontIfMissing: true,
        );
        hasChanges = true;
        continue;
      }

      if (event.isNotificationUpdated && event.notification != null) {
        _applyNotificationSnapshot(event.notification!);
        hasChanges = true;
        continue;
      }

      if (event.isNotificationsRead) {
        for (final id in event.notificationIds ?? const <int>[]) {
          _setLocalRead(id, isRead: true);
        }
        if (event.unreadCount != null) {
          _unreadCount = event.unreadCount!;
        }
        hasChanges = true;
        continue;
      }

      if (event.isNotificationsReadAll) {
        _notifications = <ActivityNotificationDto>[
          for (final item in _notifications)
            item.isRead ? item : item.copyWith(isRead: true),
        ];
        _unreadCount = event.unreadCount ?? 0;
        hasChanges = true;
        continue;
      }
    }

    if (hasChanges) {
      _notifySafely();
    }
  }

  // 未读数按最终状态幂等更新，避免重复创建事件把计数加爆。
  void _applyNotificationSnapshot(
    ActivityNotificationDto notification, {
    bool insertAtFrontIfMissing = false,
  }) {
    final previous = _findNotification(notification.id);
    final wasUnread = previous != null && _isUnreadNotification(previous);
    final isUnread = _isUnreadNotification(notification);

    if (!wasUnread && isUnread) {
      _unreadCount += 1;
    } else if (wasUnread && !isUnread) {
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    }

    _upsertNotification(
      notification,
      insertAtFront: previous == null && insertAtFrontIfMissing,
    );
  }

  bool _isUnreadNotification(ActivityNotificationDto notification) {
    return !notification.isRead;
  }

  /// 仅改本地某条通知的已读状态（不动未读数；未读数由调用方/服务端负责）。
  void _setLocalRead(int id, {required bool isRead}) {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index < 0 || _notifications[index].isRead == isRead) {
      return;
    }
    final next = List<ActivityNotificationDto>.from(_notifications);
    next[index] = next[index].copyWith(isRead: isRead);
    _notifications = next;
  }

  void _upsertNotification(
    ActivityNotificationDto notification, {
    bool insertAtFront = false,
  }) {
    final matchesFilter = _matchesNotificationFilter(notification);
    final nextItems = List<ActivityNotificationDto>.from(_notifications);
    final index = nextItems.indexWhere((item) => item.id == notification.id);
    if (!matchesFilter) {
      if (index >= 0) {
        nextItems.removeAt(index);
      }
      _notifications = _sortNotifications(nextItems);
      return;
    }

    if (index >= 0) {
      nextItems[index] = nextItems[index].mergeFromServer(notification);
    } else if (insertAtFront) {
      nextItems.insert(0, notification);
    } else {
      nextItems.add(notification);
    }
    _notifications = _sortNotifications(nextItems);
  }

  ActivityNotificationDto? _findNotification(int id) {
    for (final item in _notifications) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  bool _matchesNotificationFilter(ActivityNotificationDto item) {
    if (_filter.category != null && _filter.category != item.category) {
      return false;
    }
    return true;
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

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _resetPendingStreamEvents() {
    _pendingStreamEvents.clear();
    _isStreamFlushScheduled = false;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
