import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

class DesktopActivityPage extends StatefulWidget {
  const DesktopActivityPage({super.key});

  @override
  State<DesktopActivityPage> createState() => _DesktopActivityPageState();
}

class _DesktopActivityPageState extends State<DesktopActivityPage>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreTriggerOffset = 300;
  static const double _autoReadVisibilityThreshold = 0.5;
  static const Duration _autoReadDelay = Duration(milliseconds: 800);

  late final ActivityCenterController _controller;
  late final TabController _tabController;
  late final ScrollController _pageScrollController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final Map<int, GlobalKey> _notificationVisibilityKeys = <int, GlobalKey>{};
  final Map<int, Timer> _autoReadTimers = <int, Timer>{};
  final Set<int> _visibleNotificationIds = <int>{};
  final Set<int> _autoReadInFlightIds = <int>{};
  final Set<int> _autoReadFailedWhileVisibleIds = <int>{};
  bool _isViewportWorkScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller =
        ActivityCenterController(activityApi: context.read<ActivityApi>())
          ..addListener(_syncTabSelection)
          ..addListener(_handleControllerChanged);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _pageScrollController = ScrollController()..addListener(_handlePageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleViewportWork();
      }
    });
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncTabSelection)
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    for (final timer in _autoReadTimers.values) {
      timer.cancel();
    }
    _autoReadTimers.clear();
    _pageScrollController
      ..removeListener(_handlePageScroll)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      _controller.setActiveTab(ActivityTab.values[_tabController.index]);
    }
  }

  void _syncTabSelection() {
    if (_tabController.index != _controller.activeTab.index) {
      _tabController.animateTo(_controller.activeTab.index);
    }
  }

  void _handleControllerChanged() {
    _scheduleViewportWork();
  }

  void _handlePageScroll() {
    _maybeAutoLoadMore();
    _updateAutoReadCandidates();
  }

  void _scheduleViewportWork() {
    if (_isViewportWorkScheduled || !mounted) {
      return;
    }
    _isViewportWorkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isViewportWorkScheduled = false;
      if (!mounted) {
        return;
      }
      _maybeAutoLoadMore();
      _updateAutoReadCandidates();
    });
  }

  void _maybeAutoLoadMore() {
    if (!_pageScrollController.hasClients ||
        _controller.isInitialLoading ||
        _controller.initialErrorMessage != null) {
      return;
    }
    if (!_shouldAutoLoadMoreForViewport()) {
      return;
    }

    switch (_controller.activeTab) {
      case ActivityTab.notifications:
        if (_controller.hasMoreNotifications &&
            !_controller.isLoadingMoreNotifications &&
            _controller.notificationLoadMoreErrorMessage == null) {
          unawaited(_controller.loadMoreNotifications());
        }
        break;
      case ActivityTab.tasks:
        if (_controller.hasMoreTasks &&
            !_controller.isLoadingMoreTasks &&
            _controller.taskLoadMoreErrorMessage == null) {
          unawaited(_controller.loadMoreTasks());
        }
        break;
    }
  }

  bool _shouldAutoLoadMoreForViewport() {
    final position = _pageScrollController.position;
    if (position.maxScrollExtent <= 0) {
      return true;
    }
    return position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset;
  }

  GlobalKey _notificationVisibilityKey(int notificationId) {
    return _notificationVisibilityKeys.putIfAbsent(
      notificationId,
      () => GlobalKey(
        debugLabel: 'activity-notification-visibility-$notificationId',
      ),
    );
  }

  void _updateAutoReadCandidates() {
    final notificationIds =
        _controller.notifications.map((item) => item.id).toSet();
    _notificationVisibilityKeys.removeWhere(
      (notificationId, _) => !notificationIds.contains(notificationId),
    );

    if (_controller.activeTab != ActivityTab.notifications ||
        !_pageScrollController.hasClients) {
      _clearAutoReadState();
      return;
    }

    final eligibleIds = <int>{};
    for (final notification in _controller.notifications) {
      if (notification.isRead || notification.archived) {
        continue;
      }
      if (_visibleFractionForNotification(notification.id) <
          _autoReadVisibilityThreshold) {
        continue;
      }
      eligibleIds.add(notification.id);
    }

    for (final notificationId in _visibleNotificationIds.difference(
      eligibleIds,
    )) {
      _cancelAutoReadTimer(notificationId);
      _autoReadFailedWhileVisibleIds.remove(notificationId);
    }

    _autoReadInFlightIds.removeWhere((id) => !notificationIds.contains(id));
    _autoReadFailedWhileVisibleIds.removeWhere(
      (id) => !eligibleIds.contains(id),
    );

    for (final notificationId in eligibleIds) {
      final isNewlyVisible = !_visibleNotificationIds.contains(notificationId);
      if (!isNewlyVisible ||
          _autoReadInFlightIds.contains(notificationId) ||
          _autoReadFailedWhileVisibleIds.contains(notificationId) ||
          _autoReadTimers.containsKey(notificationId)) {
        continue;
      }
      _autoReadTimers[notificationId] = Timer(
        _autoReadDelay,
        () => _handleAutoReadTimer(notificationId),
      );
    }

    _visibleNotificationIds
      ..clear()
      ..addAll(eligibleIds);
  }

  Future<void> _handleAutoReadTimer(int notificationId) async {
    _autoReadTimers.remove(notificationId);
    if (!mounted ||
        _autoReadInFlightIds.contains(notificationId) ||
        !_visibleNotificationIds.contains(notificationId) ||
        !_isNotificationEligibleForAutoRead(notificationId)) {
      return;
    }

    _autoReadInFlightIds.add(notificationId);
    try {
      await _controller.markNotificationRead(notificationId);
    } catch (_) {
      if (mounted && _visibleNotificationIds.contains(notificationId)) {
        _autoReadFailedWhileVisibleIds.add(notificationId);
      }
    } finally {
      _autoReadInFlightIds.remove(notificationId);
    }
  }

  bool _isNotificationEligibleForAutoRead(int notificationId) {
    ActivityNotificationDto? notification;
    for (final item in _controller.notifications) {
      if (item.id == notificationId) {
        notification = item;
        break;
      }
    }
    if (notification == null || notification.isRead || notification.archived) {
      return false;
    }
    return _visibleFractionForNotification(notificationId) >=
        _autoReadVisibilityThreshold;
  }

  double _visibleFractionForNotification(int notificationId) {
    final key = _notificationVisibilityKeys[notificationId];
    final context = key?.currentContext;
    if (context == null) {
      return 0;
    }
    final itemRenderObject = context.findRenderObject();
    final viewportRenderObject =
        _pageScrollController.position.context.notificationContext
            ?.findRenderObject();
    if (itemRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !itemRenderObject.hasSize ||
        !viewportRenderObject.hasSize ||
        !itemRenderObject.attached ||
        !viewportRenderObject.attached) {
      return 0;
    }
    final itemRect =
        itemRenderObject.localToGlobal(Offset.zero) & itemRenderObject.size;
    final viewportRect =
        viewportRenderObject.localToGlobal(Offset.zero) &
        viewportRenderObject.size;
    final visibleRect = itemRect.intersect(viewportRect);
    if (visibleRect.isEmpty) {
      return 0;
    }
    final itemArea = itemRect.width * itemRect.height;
    if (itemArea <= 0) {
      return 0;
    }
    return ((visibleRect.width * visibleRect.height) / itemArea).clamp(0, 1);
  }

  void _clearAutoReadState() {
    for (final timer in _autoReadTimers.values) {
      timer.cancel();
    }
    _autoReadTimers.clear();
    _visibleNotificationIds.clear();
    _autoReadFailedWhileVisibleIds.clear();
    _autoReadInFlightIds.clear();
  }

  void _cancelAutoReadTimer(int notificationId) {
    _autoReadTimers.remove(notificationId)?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppPageFrame(
          title: '',
          scrollController: _pageScrollController,
          child: Column(
            key: const Key('desktop-activity-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(key: Key('activity-tab-notifications'), text: '通知'),
                  Tab(key: Key('activity-tab-tasks'), text: '任务'),
                ],
              ),
              SizedBox(height: context.appSpacing.lg),
              _ConnectionBanner(
                state: _controller.connectionState,
                message: _controller.connectionMessage,
              ),
              SizedBox(height: context.appSpacing.xl),
              if (_controller.isInitialLoading)
                const _InitialLoadingState()
              else if (_controller.initialErrorMessage != null)
                _InitialErrorState(
                  message: _controller.initialErrorMessage!,
                  onRetry: _controller.reloadAll,
                )
              else
                switch (_controller.activeTab) {
                  ActivityTab.notifications => _NotificationsTab(
                    controller: _controller,
                    dateFormat: _dateFormat,
                    notificationVisibilityKeyBuilder:
                        _notificationVisibilityKey,
                  ),
                  ActivityTab.tasks => _TasksTab(
                    controller: _controller,
                    dateFormat: _dateFormat,
                  ),
                },
            ],
          ),
        );
      },
    );
  }
}

class _InitialLoadingState extends StatelessWidget {
  const _InitialLoadingState();

  @override
  Widget build(BuildContext context) {
    return _ActivitySection(
      title: '活动中心',
      child: SizedBox(
        width: double.infinity,
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _InitialErrorState extends StatelessWidget {
  const _InitialErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _ActivitySection(
      title: '活动中心',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppEmptyState(message: message),
          SizedBox(height: context.appSpacing.lg),
          AppButton(label: '重试', onPressed: () => onRetry()),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.title,
    required this.child,
    this.titleStyle,
    this.spacing,
  });

  final String title;
  final Widget child;
  final TextStyle? titleStyle;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle ?? Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: spacing ?? context.appSpacing.lg),
        child,
      ],
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state, this.message});

  final ActivityConnectionState state;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final backgroundColor = switch (state) {
      ActivityConnectionState.live => Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08),
      ActivityConnectionState.connecting => colors.surfaceMuted,
      ActivityConnectionState.reconnecting => const Color(0xFFFFF4E5),
      ActivityConnectionState.polling => const Color(0xFFEFF6FF),
    };
    final foregroundColor = switch (state) {
      ActivityConnectionState.live => Theme.of(context).colorScheme.primary,
      ActivityConnectionState.connecting => colors.textSecondary,
      ActivityConnectionState.reconnecting => const Color(0xFFB54708),
      ActivityConnectionState.polling => const Color(0xFF175CD3),
    };
    final icon = switch (state) {
      ActivityConnectionState.live => Icons.bolt_rounded,
      ActivityConnectionState.connecting => Icons.sync_rounded,
      ActivityConnectionState.reconnecting =>
        Icons.wifi_tethering_error_rounded,
      ActivityConnectionState.polling => Icons.schedule_rounded,
    };

    return Container(
      key: const Key('activity-connection-banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.lg,
        vertical: context.appSpacing.md,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: foregroundColor,
            size: context.appComponentTokens.iconSizeMd,
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Text(
              message ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({
    required this.controller,
    required this.dateFormat,
    required this.notificationVisibilityKeyBuilder,
  });

  final ActivityCenterController controller;
  final DateFormat dateFormat;
  final GlobalKey Function(int notificationId) notificationVisibilityKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    return Column(
      key: const Key('activity-notifications-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivitySection(
          title: '通知中心',
          titleStyle: titleStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationFilterBar(controller: controller),
              if (controller.notificationRefreshErrorMessage != null) ...[
                SizedBox(height: context.appSpacing.md),
                AppPagedLoadMoreFooter(
                  isLoading: false,
                  errorMessage: controller.notificationRefreshErrorMessage,
                  onRetry: controller.refreshNotifications,
                ),
              ],
              SizedBox(height: context.appSpacing.lg),
              if (controller.notifications.isEmpty)
                const AppEmptyState(message: '当前筛选下暂无通知')
              else
                Column(
                  children: [
                    for (final item in controller.notifications) ...[
                      _NotificationCard(
                        visibilityKey: notificationVisibilityKeyBuilder(
                          item.id,
                        ),
                        notification: item,
                        dateFormat: dateFormat,
                        onArchive:
                            item.archived
                                ? null
                                : () async {
                                  try {
                                    await controller.archiveNotification(
                                      item.id,
                                    );
                                  } catch (error) {
                                    if (context.mounted) {
                                      showToast(
                                        apiErrorMessage(
                                          error,
                                          fallback: '归档通知失败，请稍后重试',
                                        ),
                                      );
                                    }
                                  }
                                },
                        onViewTask:
                            item.relatedTaskRunId == null
                                ? null
                                : () => controller.setActiveTab(
                                  ActivityTab.tasks,
                                  highlightTaskRunId: item.relatedTaskRunId,
                                ),
                        onViewMovie:
                            item.canOpenMovie
                                ? () =>
                                    context.goPrimaryRoute(desktopMoviesPath)
                                : null,
                      ),
                      if (item != controller.notifications.last)
                        SizedBox(height: context.appSpacing.md),
                    ],
                    SizedBox(height: context.appSpacing.lg),
                    AppPagedLoadMoreFooter(
                      isLoading: controller.isLoadingMoreNotifications,
                      errorMessage: controller.notificationLoadMoreErrorMessage,
                      onRetry: controller.loadMoreNotifications,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.controller, required this.dateFormat});

  final ActivityCenterController controller;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    return Column(
      key: const Key('activity-tasks-tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.activeTaskRuns.isNotEmpty) ...[
          _ActivitySection(
            title: '活动任务',
            titleStyle: titleStyle,
            child: Column(
              children: [
                for (final item in controller.activeTaskRuns) ...[
                  _TaskRunCard(
                    taskRun: item,
                    dateFormat: dateFormat,
                    highlighted: controller.highlightedTaskRunId == item.id,
                  ),
                  if (item != controller.activeTaskRuns.last)
                    SizedBox(height: context.appSpacing.md),
                ],
              ],
            ),
          ),
          SizedBox(height: context.appSpacing.xl),
        ],
        _ActivitySection(
          title: '任务历史',
          titleStyle: titleStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskFilterBar(controller: controller),
              if (controller.taskRefreshErrorMessage != null) ...[
                SizedBox(height: context.appSpacing.md),
                AppPagedLoadMoreFooter(
                  isLoading: false,
                  errorMessage: controller.taskRefreshErrorMessage,
                  onRetry: controller.refreshTaskHistory,
                ),
              ],
              SizedBox(height: context.appSpacing.lg),
              if (controller.taskRuns.isEmpty)
                const AppEmptyState(message: '当前筛选下暂无任务记录')
              else
                Column(
                  children: [
                    for (final item in controller.taskRuns) ...[
                      _TaskRunCard(
                        taskRun: item,
                        dateFormat: dateFormat,
                        highlighted: controller.highlightedTaskRunId == item.id,
                      ),
                      if (item != controller.taskRuns.last)
                        SizedBox(height: context.appSpacing.md),
                    ],
                    SizedBox(height: context.appSpacing.lg),
                    AppPagedLoadMoreFooter(
                      isLoading: controller.isLoadingMoreTasks,
                      errorMessage: controller.taskLoadMoreErrorMessage,
                      onRetry: controller.loadMoreTasks,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({required this.controller});

  final ActivityCenterController controller;

  static const List<String> _categories = <String>[
    'result',
    'reminder',
    'exception',
  ];
  static const List<String> _levels = <String>['info', 'warning', 'error'];

  @override
  Widget build(BuildContext context) {
    final filterTextStyle = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: 180,
          child: AppSelectField<String?>(
            key: const Key('activity-notification-category-filter'),
            value: controller.notificationFilter.category,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(value: null, child: Text('全部分类')),
              ..._categories.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForNotificationCategory(value)),
                ),
              ),
            ],
            onChanged:
                controller.isRefreshingNotifications
                    ? null
                    : (value) => controller.applyNotificationFilter(
                      controller.notificationFilter.copyWith(category: value),
                    ),
          ),
        ),
        SizedBox(
          width: 180,
          child: AppSelectField<String?>(
            key: const Key('activity-notification-level-filter'),
            value: controller.notificationFilter.level,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(value: null, child: Text('全部等级')),
              ..._levels.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForNotificationLevel(value)),
                ),
              ),
            ],
            onChanged:
                controller.isRefreshingNotifications
                    ? null
                    : (value) => controller.applyNotificationFilter(
                      controller.notificationFilter.copyWith(level: value),
                    ),
          ),
        ),
        SizedBox(
          width: 160,
          child: AppSelectField<ActivityNotificationArchivedFilter>(
            key: const Key('activity-notification-archived-filter'),
            value: controller.notificationFilter.archivedFilter,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: ActivityNotificationArchivedFilter.values
                .map(
                  (value) =>
                      DropdownMenuItem<ActivityNotificationArchivedFilter>(
                        value: value,
                        child: Text(value.label),
                      ),
                )
                .toList(growable: false),
            onChanged:
                controller.isRefreshingNotifications
                    ? null
                    : (value) => controller.applyNotificationFilter(
                      controller.notificationFilter.copyWith(
                        archivedFilter:
                            value ?? ActivityNotificationArchivedFilter.active,
                      ),
                    ),
          ),
        ),
        _FilterRefreshIndicator(
          indicatorKey: const Key('activity-notification-filter-loading'),
          isVisible: controller.isRefreshingNotifications,
        ),
      ],
    );
  }
}

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({required this.controller});

  final ActivityCenterController controller;

  static const List<String> _states = <String>[
    'running',
    'completed',
    'failed',
  ];
  static const List<String> _triggerTypes = <String>[
    'scheduled',
    'manual',
    'startup',
    'internal',
  ];

  @override
  Widget build(BuildContext context) {
    final filterTextStyle = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: 180,
          child: AppSelectField<String?>(
            key: const Key('activity-task-state-filter'),
            value: controller.taskFilter.state,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(value: null, child: Text('全部状态')),
              ..._states.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForTaskState(value)),
                ),
              ),
            ],
            onChanged:
                controller.isRefreshingTaskHistory
                    ? null
                    : (value) => controller.applyTaskFilter(
                      controller.taskFilter.copyWith(state: value),
                    ),
          ),
        ),
        SizedBox(
          width: 200,
          child: AppSelectField<String?>(
            key: const Key('activity-task-key-filter'),
            value: controller.taskFilter.taskKey,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('全部任务类型'),
              ),
              ...controller.knownTaskKeys.map(
                (value) =>
                    DropdownMenuItem<String?>(value: value, child: Text(value)),
              ),
            ],
            onChanged:
                controller.isRefreshingTaskHistory
                    ? null
                    : (value) => controller.applyTaskFilter(
                      controller.taskFilter.copyWith(taskKey: value),
                    ),
          ),
        ),
        SizedBox(
          width: 180,
          child: AppSelectField<String?>(
            key: const Key('activity-task-trigger-filter'),
            value: controller.taskFilter.triggerType,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('全部触发来源'),
              ),
              ..._triggerTypes.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForTriggerType(value)),
                ),
              ),
            ],
            onChanged:
                controller.isRefreshingTaskHistory
                    ? null
                    : (value) => controller.applyTaskFilter(
                      controller.taskFilter.copyWith(triggerType: value),
                    ),
          ),
        ),
        SizedBox(
          width: 220,
          child: AppSelectField<ActivityTaskSort>(
            key: const Key('activity-task-sort-filter'),
            value: controller.taskFilter.sort,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: ActivityTaskSort.values
                .map(
                  (value) => DropdownMenuItem<ActivityTaskSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged:
                controller.isRefreshingTaskHistory
                    ? null
                    : (value) => controller.applyTaskFilter(
                      controller.taskFilter.copyWith(
                        sort: value ?? ActivityTaskSort.startedAtDesc,
                      ),
                    ),
          ),
        ),
        _FilterRefreshIndicator(
          indicatorKey: const Key('activity-task-filter-loading'),
          isVisible: controller.isRefreshingTaskHistory,
        ),
      ],
    );
  }
}

class _FilterRefreshIndicator extends StatelessWidget {
  const _FilterRefreshIndicator({
    required this.indicatorKey,
    required this.isVisible,
  });

  final Key indicatorKey;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child:
            isVisible
                ? SizedBox(
                  key: indicatorKey,
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator.adaptive(
                    strokeWidth: 2.2,
                  ),
                )
                : null,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.visibilityKey,
    required this.notification,
    required this.dateFormat,
    this.onArchive,
    this.onViewTask,
    this.onViewMovie,
  });

  final GlobalKey visibilityKey;
  final ActivityNotificationDto notification;
  final DateFormat dateFormat;
  final Future<void> Function()? onArchive;
  final VoidCallback? onViewTask;
  final VoidCallback? onViewMovie;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return SizedBox(
      key: visibilityKey,
      width: double.infinity,
      child: Container(
        key: Key('activity-notification-${notification.id}'),
        width: double.infinity,
        padding: EdgeInsets.all(context.appSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        notification.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                _Badge(
                  label: _labelForNotificationLevel(notification.level),
                  foregroundColor: _notificationLevelColor(
                    context,
                    notification.level,
                  ),
                  backgroundColor: _notificationLevelColor(
                    context,
                    notification.level,
                  ).withValues(alpha: 0.10),
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.md),
            Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Badge(
                  label: _labelForNotificationCategory(notification.category),
                  foregroundColor: colors.textSecondary,
                  backgroundColor: colors.surfaceMuted,
                ),
                Text(
                  _formatDate(notification.createdAt, dateFormat),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.md),
            Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.sm,
              children: [
                if (onArchive != null)
                  AppButton(
                    label: '归档',
                    size: AppButtonSize.xSmall,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => onArchive!(),
                  ),
                if (onViewTask != null)
                  AppButton(
                    label: '查看任务',
                    size: AppButtonSize.xSmall,
                    variant: AppButtonVariant.secondary,
                    onPressed: onViewTask,
                  ),
                if (onViewMovie != null)
                  AppButton(
                    label: '查看影片',
                    size: AppButtonSize.xSmall,
                    variant: AppButtonVariant.secondary,
                    onPressed: onViewMovie,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRunCard extends StatelessWidget {
  const _TaskRunCard({
    required this.taskRun,
    required this.dateFormat,
    required this.highlighted,
  });

  final TaskRunDto taskRun;
  final DateFormat dateFormat;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final progressValue = taskRun.progressValue;

    return Container(
      key: Key('activity-task-${taskRun.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(
          color:
              highlighted
                  ? Theme.of(context).colorScheme.primary
                  : colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskRun.taskName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((taskRun.progressText ?? '').trim().isNotEmpty) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        taskRun.progressText!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.appSpacing.md),
              _Badge(
                label: _labelForTaskState(taskRun.state),
                foregroundColor: _taskStateColor(context, taskRun.state),
                backgroundColor: _taskStateColor(
                  context,
                  taskRun.state,
                ).withValues(alpha: 0.10),
              ),
            ],
          ),
          if (taskRun.isActive) ...[
            SizedBox(height: context.appSpacing.md),
            ClipRRect(
              borderRadius: context.appRadius.pillBorder,
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progressValue,
                backgroundColor: colors.surfaceMuted,
              ),
            ),
          ],
          SizedBox(height: context.appSpacing.md),
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: [
              _Badge(
                label: _labelForTriggerType(taskRun.triggerType),
                foregroundColor: colors.textSecondary,
                backgroundColor: colors.surfaceMuted,
              ),
              Text(
                _taskTimeSummary(taskRun, dateFormat),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          if ((taskRun.displaySummary ?? '').trim().isNotEmpty) ...[
            SizedBox(height: context.appSpacing.md),
            Text(
              taskRun.displaySummary!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value, DateFormat formatter) {
  if (value == null) {
    return '时间未知';
  }
  return formatter.format(value.toLocal());
}

String _taskTimeSummary(TaskRunDto item, DateFormat formatter) {
  if (item.finishedAt != null) {
    return '完成于 ${_formatDate(item.finishedAt, formatter)}';
  }
  if (item.startedAt != null) {
    return '开始于 ${_formatDate(item.startedAt, formatter)}';
  }
  return '创建于 ${_formatDate(item.createdAt, formatter)}';
}

Color _notificationLevelColor(BuildContext context, String level) {
  return switch (level) {
    'error' => const Color(0xFFB42318),
    'warning' => const Color(0xFFB54708),
    _ => Theme.of(context).colorScheme.primary,
  };
}

Color _taskStateColor(BuildContext context, String state) {
  return switch (state) {
    'failed' => const Color(0xFFB42318),
    'completed' => const Color(0xFF027A48),
    'running' => Theme.of(context).colorScheme.primary,
    'pending' => const Color(0xFFB54708),
    _ => context.appColors.textSecondary,
  };
}

String _labelForNotificationCategory(String value) {
  return switch (value) {
    'result' => '结果',
    'reminder' => '提醒',
    'exception' => '异常',
    _ => value,
  };
}

String _labelForNotificationLevel(String value) {
  return switch (value) {
    'info' => '信息',
    'warning' => '警告',
    'error' => '错误',
    _ => value,
  };
}

String _labelForTaskState(String value) {
  return switch (value) {
    'running' => '运行中',
    'completed' => '已完成',
    'failed' => '失败',
    'pending' => '排队中',
    _ => value,
  };
}

String _labelForTriggerType(String value) {
  return switch (value) {
    'scheduled' => '定时触发',
    'manual' => '手动触发',
    'startup' => '启动触发',
    'internal' => '内部触发',
    _ => value,
  };
}
