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
}

const Object _sentinel = Object();
