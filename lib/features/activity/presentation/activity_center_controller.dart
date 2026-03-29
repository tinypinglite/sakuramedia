import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_stream_event.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';

enum ActivityTab { notifications, tasks }

enum ActivityConnectionState { connecting, live, reconnecting, polling }

class ActivityCenterController extends ChangeNotifier {
  ActivityCenterController({required ActivityApi activityApi})
    : _activityApi = activityApi;

  static const int _pageSize = 20;
  static const Duration _longDisconnectThreshold = Duration(minutes: 2);
  static const Duration _pollingInterval = Duration(seconds: 30);
  static const List<Duration> _reconnectDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  final ActivityApi _activityApi;

  ActivityTab _activeTab = ActivityTab.notifications;
  ActivityConnectionState _connectionState = ActivityConnectionState.connecting;
  String? _connectionMessage;
  bool _initialized = false;
  bool _isInitialLoading = false;
  String? _initialErrorMessage;
  int _unreadCount = 0;
  int _lastEventId = 0;
  int _notificationNextPage = 1;
  int _taskNextPage = 1;
  bool _hasMoreNotifications = true;
  bool _hasMoreTasks = true;
  bool _isLoadingMoreNotifications = false;
  bool _isLoadingMoreTasks = false;
  bool _isRefreshingNotifications = false;
  bool _isRefreshingTaskHistory = false;
  String? _notificationLoadMoreErrorMessage;
  String? _taskLoadMoreErrorMessage;
  String? _notificationRefreshErrorMessage;
  String? _taskRefreshErrorMessage;
  ActivityNotificationFilterState _notificationFilter =
      ActivityNotificationFilterState.initial;
  ActivityTaskFilterState _taskFilter = ActivityTaskFilterState.initial;
  List<ActivityNotificationDto> _notifications =
      const <ActivityNotificationDto>[];
  List<TaskRunDto> _activeTaskRuns = const <TaskRunDto>[];
  List<TaskRunDto> _taskRuns = const <TaskRunDto>[];
  int? _highlightedTaskRunId;
  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  StreamSubscription<ActivityStreamEvent>? _eventSubscription;
  DateTime? _disconnectStartedAt;
  int _reconnectAttempt = 0;
  int _notificationRefreshRequestId = 0;
  int _taskRefreshRequestId = 0;
  bool _disposed = false;

  bool get initialized => _initialized;
  bool get isInitialLoading => _isInitialLoading;
  String? get initialErrorMessage => _initialErrorMessage;
  ActivityTab get activeTab => _activeTab;
  ActivityConnectionState get connectionState => _connectionState;
  String? get connectionMessage => _connectionMessage;
  int get unreadCount => _unreadCount;
  ActivityNotificationFilterState get notificationFilter => _notificationFilter;
  ActivityTaskFilterState get taskFilter => _taskFilter;
  UnmodifiableListView<ActivityNotificationDto> get notifications =>
      UnmodifiableListView<ActivityNotificationDto>(_notifications);
  UnmodifiableListView<TaskRunDto> get activeTaskRuns =>
      UnmodifiableListView<TaskRunDto>(_activeTaskRuns);
  UnmodifiableListView<TaskRunDto> get taskRuns =>
      UnmodifiableListView<TaskRunDto>(_taskRuns);
  bool get hasMoreNotifications => _hasMoreNotifications;
  bool get hasMoreTasks => _hasMoreTasks;
  bool get isLoadingMoreNotifications => _isLoadingMoreNotifications;
  bool get isLoadingMoreTasks => _isLoadingMoreTasks;
  bool get isRefreshingNotifications => _isRefreshingNotifications;
  bool get isRefreshingTaskHistory => _isRefreshingTaskHistory;
  String? get notificationLoadMoreErrorMessage =>
      _notificationLoadMoreErrorMessage;
  String? get taskLoadMoreErrorMessage => _taskLoadMoreErrorMessage;
  String? get notificationRefreshErrorMessage =>
      _notificationRefreshErrorMessage;
  String? get taskRefreshErrorMessage => _taskRefreshErrorMessage;
  int? get highlightedTaskRunId => _highlightedTaskRunId;
  bool get isPollingFallback =>
      _connectionState == ActivityConnectionState.polling;
  List<String> get knownTaskKeys {
    final values = <String>{};
    for (final item in <TaskRunDto>[..._activeTaskRuns, ..._taskRuns]) {
      if (item.taskKey.trim().isNotEmpty) {
        values.add(item.taskKey);
      }
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  Future<void> initialize() async {
    if (_initialized || _isInitialLoading) {
      return;
    }
    await reloadAll();
  }

  Future<void> reloadAll() async {
    _notificationRefreshRequestId += 1;
    _taskRefreshRequestId += 1;
    _cancelReconnectTimer();
    _cancelPollingTimer();
    await _eventSubscription?.cancel();
    _eventSubscription = null;

    _isInitialLoading = true;
    _isRefreshingNotifications = false;
    _isRefreshingTaskHistory = false;
    _initialErrorMessage = null;
    _notificationRefreshErrorMessage = null;
    _taskRefreshErrorMessage = null;
    _connectionState = ActivityConnectionState.connecting;
    _connectionMessage = '正在同步活动中心';
    _notifySafely();

    try {
      await _loadFirstPageState();
      _initialized = true;
      _isInitialLoading = false;
      _initialErrorMessage = null;
      _notifySafely();
      await _connectStream();
    } catch (error) {
      _isInitialLoading = false;
      _initialErrorMessage = apiErrorMessage(error, fallback: '活动中心加载失败，请稍后重试');
      _connectionState = ActivityConnectionState.reconnecting;
      _connectionMessage = null;
      _notifySafely();
    }
  }

  void setActiveTab(ActivityTab tab, {int? highlightTaskRunId}) {
    if (_activeTab == tab && highlightTaskRunId == _highlightedTaskRunId) {
      return;
    }
    _activeTab = tab;
    _highlightedTaskRunId = highlightTaskRunId;
    _notifySafely();
  }

  void clearHighlightedTaskRun() {
    if (_highlightedTaskRunId == null) {
      return;
    }
    _highlightedTaskRunId = null;
    _notifySafely();
  }

  Future<void> applyNotificationFilter(
    ActivityNotificationFilterState next,
  ) async {
    if (_notificationFilter == next) {
      return;
    }
    _notificationFilter = next;
    await refreshNotifications();
  }

  Future<void> applyTaskFilter(ActivityTaskFilterState next) async {
    if (_taskFilter == next) {
      return;
    }
    _taskFilter = next;
    await refreshTaskHistory();
  }

  Future<void> refreshNotifications() async {
    final requestId = ++_notificationRefreshRequestId;
    _isRefreshingNotifications = true;
    _notificationRefreshErrorMessage = null;
    _notificationLoadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getNotifications(
        page: 1,
        pageSize: _pageSize,
        category: _notificationFilter.category,
        level: _notificationFilter.level,
        archived: _notificationFilter.archivedFilter.apiValue,
      );
      if (_disposed || requestId != _notificationRefreshRequestId) {
        return;
      }
      _notifications = _sortNotifications(response.items);
      _notificationNextPage = response.page + 1;
      _hasMoreNotifications = _notifications.length < response.total;
      _notificationLoadMoreErrorMessage = null;
      _notificationRefreshErrorMessage = null;
    } catch (_) {
      if (_disposed || requestId != _notificationRefreshRequestId) {
        return;
      }
      _notificationRefreshErrorMessage = '通知筛选刷新失败，请重试';
    } finally {
      if (!_disposed && requestId == _notificationRefreshRequestId) {
        _isRefreshingNotifications = false;
        _notifySafely();
      }
    }
  }

  Future<void> refreshTaskHistory() async {
    final requestId = ++_taskRefreshRequestId;
    _isRefreshingTaskHistory = true;
    _taskRefreshErrorMessage = null;
    _taskLoadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getTaskRuns(
        page: 1,
        pageSize: _pageSize,
        state: _taskFilter.state,
        taskKey: _taskFilter.taskKey,
        triggerType: _taskFilter.triggerType,
        sort: _taskFilter.sort.apiValue,
      );
      if (_disposed || requestId != _taskRefreshRequestId) {
        return;
      }
      _taskRuns = _sortHistoryTasks(response.items);
      _taskNextPage = response.page + 1;
      _hasMoreTasks = _taskRuns.length < response.total;
      _taskLoadMoreErrorMessage = null;
      _taskRefreshErrorMessage = null;
    } catch (_) {
      if (_disposed || requestId != _taskRefreshRequestId) {
        return;
      }
      _taskRefreshErrorMessage = '任务筛选刷新失败，请重试';
    } finally {
      if (!_disposed && requestId == _taskRefreshRequestId) {
        _isRefreshingTaskHistory = false;
        _notifySafely();
      }
    }
  }

  Future<void> loadMoreNotifications() async {
    if (_isLoadingMoreNotifications ||
        _isRefreshingNotifications ||
        !_hasMoreNotifications) {
      return;
    }
    _isLoadingMoreNotifications = true;
    _notificationLoadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getNotifications(
        page: _notificationNextPage,
        pageSize: _pageSize,
        category: _notificationFilter.category,
        level: _notificationFilter.level,
        archived: _notificationFilter.archivedFilter.apiValue,
      );
      _notifications = <ActivityNotificationDto>[
        ..._notifications,
        ...response.items.where(
          (item) => !_notifications.any((it) => it.id == item.id),
        ),
      ];
      _notificationNextPage = response.page + 1;
      _hasMoreNotifications = _notifications.length < response.total;
      _notificationLoadMoreErrorMessage = null;
    } catch (error) {
      _notificationLoadMoreErrorMessage = '加载更多通知失败，请点击重试';
    } finally {
      _isLoadingMoreNotifications = false;
      _notifySafely();
    }
  }

  Future<void> loadMoreTasks() async {
    if (_isLoadingMoreTasks || _isRefreshingTaskHistory || !_hasMoreTasks) {
      return;
    }
    _isLoadingMoreTasks = true;
    _taskLoadMoreErrorMessage = null;
    _notifySafely();

    try {
      final response = await _activityApi.getTaskRuns(
        page: _taskNextPage,
        pageSize: _pageSize,
        state: _taskFilter.state,
        taskKey: _taskFilter.taskKey,
        triggerType: _taskFilter.triggerType,
        sort: _taskFilter.sort.apiValue,
      );
      _taskRuns = _appendUniqueTasks(_taskRuns, response.items);
      _taskNextPage = response.page + 1;
      _hasMoreTasks = _taskRuns.length < response.total;
      _taskLoadMoreErrorMessage = null;
    } catch (error) {
      _taskLoadMoreErrorMessage = '加载更多任务失败，请点击重试';
    } finally {
      _isLoadingMoreTasks = false;
      _notifySafely();
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    final current = _findNotification(notificationId);
    if (current == null || current.isRead) {
      return;
    }

    await _activityApi.markNotificationRead(notificationId: notificationId);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    _upsertNotification(current.copyWith(isRead: true));
    _notifySafely();
  }

  Future<void> archiveNotification(int notificationId) async {
    final current = _findNotification(notificationId);
    if (current == null || current.archived) {
      return;
    }

    await _activityApi.archiveNotification(notificationId: notificationId);
    if (!current.isRead) {
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    }
    _upsertNotification(current.copyWith(archived: true));
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFirstPageState() async {
    final notificationFuture = _activityApi.getNotifications(
      page: 1,
      pageSize: _pageSize,
      category: _notificationFilter.category,
      level: _notificationFilter.level,
      archived: _notificationFilter.archivedFilter.apiValue,
    );
    final unreadFuture = _activityApi.getUnreadCount();
    final activeTasksFuture = _activityApi.getActiveTaskRuns();
    final taskRunsFuture = _activityApi.getTaskRuns(
      page: 1,
      pageSize: _pageSize,
      state: _taskFilter.state,
      taskKey: _taskFilter.taskKey,
      triggerType: _taskFilter.triggerType,
      sort: _taskFilter.sort.apiValue,
    );

    final results = await Future.wait<Object>(<Future<Object>>[
      notificationFuture,
      unreadFuture,
      activeTasksFuture,
      taskRunsFuture,
    ]);

    final notificationResponse =
        results[0] as PaginatedResponseDto<ActivityNotificationDto>;
    final unreadCount = results[1] as int;
    final activeItems = results[2] as List<TaskRunDto>;
    final taskResponse = results[3] as PaginatedResponseDto<TaskRunDto>;

    _notifications = notificationResponse.items;
    _unreadCount = unreadCount;
    _activeTaskRuns = _sortActiveTasks(activeItems);
    _taskRuns = _sortHistoryTasks(taskResponse.items);
    _notificationNextPage = notificationResponse.page + 1;
    _taskNextPage = taskResponse.page + 1;
    _hasMoreNotifications = _notifications.length < notificationResponse.total;
    _hasMoreTasks = _taskRuns.length < taskResponse.total;
    _notificationLoadMoreErrorMessage = null;
    _taskLoadMoreErrorMessage = null;
    _notificationRefreshErrorMessage = null;
    _taskRefreshErrorMessage = null;
  }

  Future<void> _connectStream() async {
    _cancelReconnectTimer();
    _cancelPollingTimer();
    _connectionState = ActivityConnectionState.connecting;
    _connectionMessage = '正在连接实时活动流';
    _notifySafely();

    if (_disconnectStartedAt != null &&
        DateTime.now().difference(_disconnectStartedAt!) >
            _longDisconnectThreshold) {
      try {
        await _loadFirstPageState();
      } catch (_) {
        // Ignore REST recovery failures here and continue reconnecting.
      }
    }

    final stream = _activityApi.streamEvents(afterEventId: _lastEventId);
    _eventSubscription = stream.listen(
      _handleStreamEvent,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
      cancelOnError: false,
    );
    _connectionState = ActivityConnectionState.live;
    _connectionMessage = '实时连接中';
    _reconnectAttempt = 0;
    _disconnectStartedAt = null;
    _notifySafely();
  }

  void _handleStreamEvent(ActivityStreamEvent event) {
    if (event.id != null && event.id! > _lastEventId) {
      _lastEventId = event.id!;
    }

    if (event.isHeartbeat) {
      const liveMessage = '实时连接中';
      final hasStateChanged =
          _connectionState != ActivityConnectionState.live ||
          _connectionMessage != liveMessage;
      _connectionState = ActivityConnectionState.live;
      _connectionMessage = liveMessage;
      if (hasStateChanged) {
        _notifySafely();
      }
      return;
    }

    if (event.isNotificationCreated && event.notification != null) {
      final notification = event.notification!;
      if (!notification.archived && !notification.isRead) {
        _unreadCount += 1;
      }
      _upsertNotification(notification, insertAtFront: true);
      _notifySafely();
      return;
    }

    if (event.isNotificationUpdated && event.notification != null) {
      final incoming = event.notification!;
      final previous = _findNotification(incoming.id);
      if (previous != null &&
          !previous.archived &&
          !previous.isRead &&
          (incoming.archived || incoming.isRead)) {
        _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
      }
      _upsertNotification(incoming);
      _notifySafely();
      return;
    }

    if (event.isTaskRunCreated && event.taskRun != null) {
      _upsertTaskRun(event.taskRun!, insertAtFront: true);
      _notifySafely();
      return;
    }

    if (event.isTaskRunUpdated && event.taskRun != null) {
      _upsertTaskRun(event.taskRun!);
      _notifySafely();
    }
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
    _connectionState = ActivityConnectionState.reconnecting;
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
    _cancelReconnectTimer();
    _connectionState = ActivityConnectionState.polling;
    _connectionMessage = '当前浏览器不支持实时连接，已切换为 30 秒轮询';
    _notifySafely();
    _cancelPollingTimer();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (_disposed) {
        return;
      }
      try {
        await _loadFirstPageState();
        _notifySafely();
      } catch (_) {
        // Keep the last known state during polling fallback failures.
      }
    });
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

  void _upsertTaskRun(TaskRunDto taskRun, {bool insertAtFront = false}) {
    _activeTaskRuns = _upsertTaskInList(
      _activeTaskRuns,
      taskRun,
      insertAtFront: insertAtFront,
      keepWhenMissing: taskRun.isActive,
      sorter: _sortActiveTasks,
    );
    _taskRuns = _upsertTaskInList(
      _taskRuns,
      taskRun,
      insertAtFront: insertAtFront,
      keepWhenMissing: _matchesTaskFilter(taskRun),
      sorter: _sortHistoryTasks,
    );
  }

  List<TaskRunDto> _upsertTaskInList(
    List<TaskRunDto> current,
    TaskRunDto next, {
    required bool insertAtFront,
    required bool keepWhenMissing,
    required List<TaskRunDto> Function(List<TaskRunDto>) sorter,
  }) {
    final nextItems = List<TaskRunDto>.from(current);
    final index = nextItems.indexWhere((item) => item.id == next.id);

    if (index >= 0) {
      if (!keepWhenMissing) {
        nextItems.removeAt(index);
      } else {
        nextItems[index] = nextItems[index].mergeFromServer(next);
      }
      return sorter(nextItems);
    }

    if (!keepWhenMissing) {
      return sorter(nextItems);
    }

    if (insertAtFront) {
      nextItems.insert(0, next);
    } else {
      nextItems.add(next);
    }
    return sorter(nextItems);
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
    if (_notificationFilter.category != null &&
        _notificationFilter.category != item.category) {
      return false;
    }
    if (_notificationFilter.level != null &&
        _notificationFilter.level != item.level) {
      return false;
    }
    if (item.archived != _notificationFilter.archivedFilter.apiValue) {
      return false;
    }
    return true;
  }

  bool _matchesTaskFilter(TaskRunDto item) {
    if (_taskFilter.state != null && _taskFilter.state != item.state) {
      return false;
    }
    if (_taskFilter.taskKey != null && _taskFilter.taskKey != item.taskKey) {
      return false;
    }
    if (_taskFilter.triggerType != null &&
        _taskFilter.triggerType != item.triggerType) {
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

  List<TaskRunDto> _sortActiveTasks(List<TaskRunDto> items) {
    final sorted = items.where((item) => item.isActive).toList(growable: false);
    return List<TaskRunDto>.from(sorted)..sort((left, right) {
      final leftAt = left.startedAt?.millisecondsSinceEpoch ?? 0;
      final rightAt = right.startedAt?.millisecondsSinceEpoch ?? 0;
      return rightAt.compareTo(leftAt);
    });
  }

  List<TaskRunDto> _sortHistoryTasks(List<TaskRunDto> items) {
    final filtered = items.where(_matchesTaskFilter).toList(growable: false);
    final sorted = List<TaskRunDto>.from(filtered);
    int timestampFor(TaskRunDto item, ActivityTaskSort sort) {
      return switch (sort) {
        ActivityTaskSort.startedAtDesc || ActivityTaskSort.startedAtAsc =>
          item.startedAt?.millisecondsSinceEpoch ?? 0,
        ActivityTaskSort.createdAtDesc || ActivityTaskSort.createdAtAsc =>
          item.createdAt?.millisecondsSinceEpoch ?? 0,
        ActivityTaskSort.updatedAtDesc || ActivityTaskSort.updatedAtAsc =>
          item.updatedAt?.millisecondsSinceEpoch ?? 0,
      };
    }

    sorted.sort((left, right) {
      final leftValue = timestampFor(left, _taskFilter.sort);
      final rightValue = timestampFor(right, _taskFilter.sort);
      return switch (_taskFilter.sort) {
        ActivityTaskSort.startedAtDesc ||
        ActivityTaskSort.createdAtDesc ||
        ActivityTaskSort.updatedAtDesc => rightValue.compareTo(leftValue),
        _ => leftValue.compareTo(rightValue),
      };
    });
    return sorted;
  }

  List<TaskRunDto> _appendUniqueTasks(
    List<TaskRunDto> current,
    List<TaskRunDto> incoming,
  ) {
    final next = List<TaskRunDto>.from(current);
    for (final item in incoming) {
      if (next.any((existing) => existing.id == item.id)) {
        continue;
      }
      next.add(item);
    }
    return _sortHistoryTasks(next);
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
