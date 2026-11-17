import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

enum NotificationConnectionState { connecting, polling }

@immutable
class NotificationCenterState {
  const NotificationCenterState({
    this.initialized = false,
    this.isInitialLoading = false,
    this.initialErrorMessage,
    this.unreadCount = 0,
    this.connectionState = NotificationConnectionState.connecting,
    this.connectionMessage,
    this.filter = ActivityNotificationFilterState.initial,
    this.filterUpdate = const FilterUpdateState.idle(),
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.loadMoreErrorMessage,
    this.refreshErrorMessage,
    this.isMarkingAllRead = false,
    this.notifications = const <ActivityNotificationDto>[],
  });

  static const NotificationCenterState initial = NotificationCenterState();

  final bool initialized;
  final bool isInitialLoading;
  final String? initialErrorMessage;
  final int unreadCount;
  final NotificationConnectionState connectionState;
  final String? connectionMessage;
  final ActivityNotificationFilterState filter;
  final FilterUpdateState filterUpdate;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? loadMoreErrorMessage;
  final String? refreshErrorMessage;
  final bool isMarkingAllRead;
  final List<ActivityNotificationDto> notifications;

  bool get isPollingFallback =>
      connectionState == NotificationConnectionState.polling;

  /// 当前是否允许自动请求下一页；失败后只保留页脚的显式重试。
  bool get canAutoLoadMore =>
      initialized &&
      !isInitialLoading &&
      initialErrorMessage == null &&
      filterUpdate.isIdle &&
      !isRefreshing &&
      hasMore &&
      !isLoadingMore &&
      loadMoreErrorMessage == null;

  NotificationCenterState copyWith({
    bool? initialized,
    bool? isInitialLoading,
    Object? initialErrorMessage = _sentinel,
    int? unreadCount,
    NotificationConnectionState? connectionState,
    Object? connectionMessage = _sentinel,
    ActivityNotificationFilterState? filter,
    FilterUpdateState? filterUpdate,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? loadMoreErrorMessage = _sentinel,
    Object? refreshErrorMessage = _sentinel,
    bool? isMarkingAllRead,
    List<ActivityNotificationDto>? notifications,
  }) {
    return NotificationCenterState(
      initialized: initialized ?? this.initialized,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      initialErrorMessage: identical(initialErrorMessage, _sentinel)
          ? this.initialErrorMessage
          : initialErrorMessage as String?,
      unreadCount: unreadCount ?? this.unreadCount,
      connectionState: connectionState ?? this.connectionState,
      connectionMessage: identical(connectionMessage, _sentinel)
          ? this.connectionMessage
          : connectionMessage as String?,
      filter: filter ?? this.filter,
      filterUpdate: filterUpdate ?? this.filterUpdate,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadMoreErrorMessage: identical(loadMoreErrorMessage, _sentinel)
          ? this.loadMoreErrorMessage
          : loadMoreErrorMessage as String?,
      refreshErrorMessage: identical(refreshErrorMessage, _sentinel)
          ? this.refreshErrorMessage
          : refreshErrorMessage as String?,
      isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
      notifications: List<ActivityNotificationDto>.unmodifiable(
        notifications ?? this.notifications,
      ),
    );
  }

  /// 内容相等：Riverpod 默认按 `==` 决定要不要通知订阅者（`updateShouldNotify`），
  /// 全等时跳过通知，30 秒轮询 tick / 已读回执无实质变化就不会凭空重建。
  /// 必须覆盖全部字段：漏比的字段会静默丢掉该字段的更新。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationCenterState &&
        other.initialized == initialized &&
        other.isInitialLoading == isInitialLoading &&
        other.initialErrorMessage == initialErrorMessage &&
        other.unreadCount == unreadCount &&
        other.connectionState == connectionState &&
        other.connectionMessage == connectionMessage &&
        other.filter == filter &&
        other.filterUpdate == filterUpdate &&
        other.hasMore == hasMore &&
        other.isLoadingMore == isLoadingMore &&
        other.isRefreshing == isRefreshing &&
        other.loadMoreErrorMessage == loadMoreErrorMessage &&
        other.refreshErrorMessage == refreshErrorMessage &&
        other.isMarkingAllRead == isMarkingAllRead &&
        listEquals(other.notifications, notifications);
  }

  @override
  int get hashCode => Object.hash(
    initialized,
    isInitialLoading,
    initialErrorMessage,
    unreadCount,
    connectionState,
    connectionMessage,
    filter,
    filterUpdate,
    hasMore,
    isLoadingMore,
    isRefreshing,
    loadMoreErrorMessage,
    refreshErrorMessage,
    isMarkingAllRead,
    Object.hashAll(notifications),
  );
}

const Object _sentinel = Object();
