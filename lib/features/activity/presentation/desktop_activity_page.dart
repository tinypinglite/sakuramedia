import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_center_controller.dart';
import 'package:sakuramedia/features/activity/presentation/resource_task_pane.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
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

  late final ActivityCenterController _controller;
  late final ResourceTaskCenterController _resourceTaskController;
  late final TabController _tabController;
  late final ScrollController _pageScrollController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _isViewportWorkScheduled = false;

  @override
  void initState() {
    super.initState();
    final activityApi = context.read<ActivityApi>();
    _controller =
        ActivityCenterController(activityApi: activityApi)
          ..addListener(_syncTabSelection)
          ..addListener(_handleControllerChanged);
    _resourceTaskController = ResourceTaskCenterController(
      activityApi: activityApi,
    )..addListener(_handleControllerChanged);
    _tabController = TabController(length: 3, vsync: this)
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
    _resourceTaskController
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _pageScrollController
      ..removeListener(_handlePageScroll)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      final nextTab = ActivityTab.values[_tabController.index];
      _controller.setActiveTab(nextTab);
      if (nextTab == ActivityTab.resourceTasks &&
          !_resourceTaskController.initialized &&
          !_resourceTaskController.isInitialLoading) {
        unawaited(_resourceTaskController.initialize());
      }
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
      case ActivityTab.resourceTasks:
        if (_resourceTaskController.hasMoreRecords &&
            !_resourceTaskController.isLoadingMoreRecords &&
            _resourceTaskController.recordsLoadMoreErrorMessage == null) {
          unawaited(_resourceTaskController.loadMoreRecords());
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

  Future<void> _triggerJob(JobMetadataDto job) async {
    try {
      await _controller.triggerJob(job.taskKey);
      if (mounted) {
        showToast('任务已提交');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException &&
          error.statusCode == 409 &&
          error.error?.code == 'task_conflict') {
        showToast('任务已在运行中');
        return;
      }
      showToast(apiErrorMessage(error, fallback: '任务提交失败，请重试'));
    }
  }

  List<Widget> _buildTabSlivers(BuildContext context) {
    if (_controller.isInitialLoading) {
      return const <Widget>[SliverToBoxAdapter(child: _InitialLoadingState())];
    }
    if (_controller.initialErrorMessage != null) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _InitialErrorState(
            message: _controller.initialErrorMessage!,
            onRetry: _controller.reloadAll,
          ),
        ),
      ];
    }
    return switch (_controller.activeTab) {
      ActivityTab.notifications => _buildNotificationSlivers(context),
      ActivityTab.tasks => _buildTaskSlivers(context),
      ActivityTab.resourceTasks => buildResourceTaskSlivers(
        context: context,
        controller: _resourceTaskController,
        dateFormat: _dateFormat,
      ),
    };
  }

  List<Widget> _buildNotificationSlivers(BuildContext context) {
    final titleStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s18,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    );
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          key: const Key('activity-notifications-tab'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActivitySection(
              title: '通知中心',
              titleStyle: titleStyle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationFilterBar(controller: _controller),
                  if (_controller.notificationRefreshErrorMessage != null) ...[
                    SizedBox(height: context.appSpacing.md),
                    AppPagedLoadMoreFooter(
                      isLoading: false,
                      errorMessage: _controller.notificationRefreshErrorMessage,
                      onRetry: _controller.refreshNotifications,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
          ],
        ),
      ),
    ];

    if (_controller.notifications.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(child: AppEmptyState(message: '当前筛选下暂无通知')),
      );
      return slivers;
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _controller.notifications[index];
          final isLast = index == _controller.notifications.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : context.appSpacing.md,
            ),
            child: RepaintBoundary(
              child: _NotificationCard(
                notification: item,
                dateFormat: _dateFormat,
              ),
            ),
          );
        }, childCount: _controller.notifications.length),
      ),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: _controller.isLoadingMoreNotifications,
              errorMessage: _controller.notificationLoadMoreErrorMessage,
              onRetry: _controller.loadMoreNotifications,
            ),
            SizedBox(height: context.appSpacing.xl),
          ],
        ),
      ),
    );
    return slivers;
  }

  List<Widget> _buildTaskSlivers(BuildContext context) {
    final titleStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s18,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    );
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          key: const Key('activity-tasks-tab'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_controller.activeTaskRuns.isNotEmpty) ...[
              _ActivitySection(
                title: '活动任务',
                titleStyle: titleStyle,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < _controller.activeTaskRuns.length;
                      index++
                    ) ...[
                      RepaintBoundary(
                        child: _TaskRunCard(
                          taskRun: _controller.activeTaskRuns[index],
                          dateFormat: _dateFormat,
                          highlighted:
                              _controller.highlightedTaskRunId ==
                              _controller.activeTaskRuns[index].id,
                        ),
                      ),
                      if (index != _controller.activeTaskRuns.length - 1)
                        SizedBox(height: context.appSpacing.md),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.appSpacing.xl),
            ],
            _ExecutableJobsSection(
              controller: _controller,
              dateFormat: _dateFormat,
              onTriggerJob: _triggerJob,
            ),
            SizedBox(height: context.appSpacing.xl),
            _ActivitySection(
              title: '任务历史',
              titleStyle: titleStyle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskFilterBar(controller: _controller),
                  if (_controller.taskRefreshErrorMessage != null) ...[
                    SizedBox(height: context.appSpacing.md),
                    AppPagedLoadMoreFooter(
                      isLoading: false,
                      errorMessage: _controller.taskRefreshErrorMessage,
                      onRetry: _controller.refreshTaskHistory,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
          ],
        ),
      ),
    ];

    if (_controller.taskRuns.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(child: AppEmptyState(message: '当前筛选下暂无任务记录')),
      );
      return slivers;
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _controller.taskRuns[index];
          final isLast = index == _controller.taskRuns.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : context.appSpacing.md,
            ),
            child: RepaintBoundary(
              child: _TaskRunCard(
                taskRun: item,
                dateFormat: _dateFormat,
                highlighted: _controller.highlightedTaskRunId == item.id,
              ),
            ),
          );
        }, childCount: _controller.taskRuns.length),
      ),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: _controller.isLoadingMoreTasks,
              errorMessage: _controller.taskLoadMoreErrorMessage,
              onRetry: _controller.loadMoreTasks,
            ),
            SizedBox(height: context.appSpacing.xl),
          ],
        ),
      ),
    );
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _controller,
        _resourceTaskController,
      ]),
      builder: (context, _) {
        return Stack(
          children: [
            CustomScrollView(
              controller: _pageScrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    key: const Key('desktop-activity-page'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(
                            key: Key('activity-tab-notifications'),
                            text: '通知',
                          ),
                          Tab(key: Key('activity-tab-tasks'), text: '任务'),
                          Tab(
                            key: Key('activity-tab-resource-tasks'),
                            text: '资源任务',
                          ),
                        ],
                      ),
                      SizedBox(height: context.appSpacing.lg),
                      _ConnectionBanner(
                        state: _controller.connectionState,
                        message: _controller.connectionMessage,
                      ),
                      SizedBox(height: context.appSpacing.xl),
                    ],
                  ),
                ),
                ..._buildTabSlivers(context),
              ],
            ),
            if (_controller.activeTab == ActivityTab.resourceTasks)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_resourceTaskController.isDetailOpen,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        _resourceTaskController.isDetailOpen
                            ? buildResourceTaskDetailOverlay(
                              context: context,
                              controller: _resourceTaskController,
                              dateFormat: _dateFormat,
                            )
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
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
  });

  final String title;
  final Widget child;
  final TextStyle? titleStyle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              titleStyle ??
              resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
        ),
        SizedBox(height: context.appSpacing.lg),
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
    final backgroundColor = switch (state) {
      ActivityConnectionState.live => Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08),
      ActivityConnectionState.connecting => colors.surfaceMuted,
      ActivityConnectionState.reconnecting => colors.warningSurface,
      ActivityConnectionState.polling => colors.infoSurface,
    };
    final foregroundColor = switch (state) {
      ActivityConnectionState.live => Theme.of(context).colorScheme.primary,
      ActivityConnectionState.connecting => context.appTextPalette.secondary,
      ActivityConnectionState.reconnecting => context.appTextPalette.warning,
      ActivityConnectionState.polling => context.appTextPalette.info,
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
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ).copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({required this.controller});

  final ActivityCenterController controller;

  static const List<String> _categories = <String>[
    'info',
    'warning',
    'error',
    'reminder',
  ];

  @override
  Widget build(BuildContext context) {
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<String?>(
            key: const Key('activity-notification-category-filter'),
            value: controller.notificationFilter.category,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
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
        _FilterRefreshIndicator(
          indicatorKey: const Key('activity-notification-filter-loading'),
          isVisible: controller.isRefreshingNotifications,
        ),
      ],
    );
  }
}

class _ExecutableJobsSection extends StatefulWidget {
  const _ExecutableJobsSection({
    required this.controller,
    required this.dateFormat,
    required this.onTriggerJob,
  });

  final ActivityCenterController controller;
  final DateFormat dateFormat;
  final ValueChanged<JobMetadataDto> onTriggerJob;

  @override
  State<_ExecutableJobsSection> createState() => _ExecutableJobsSectionState();
}

class _ExecutableJobsSectionState extends State<_ExecutableJobsSection> {
  bool _isExpanded = false;

  ActivityCenterController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExecutableJobsHeader(
          isExpanded: _isExpanded,
          summary: _summaryText,
          onToggle: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
        if (_isExpanded) ...[
          SizedBox(height: context.appSpacing.md),
          _buildContent(context),
        ],
      ],
    );
  }

  String get _summaryText {
    if (controller.isLoadingJobs && controller.jobs.isEmpty) {
      return '加载中';
    }
    if (controller.jobErrorMessage != null && controller.jobs.isEmpty) {
      return '加载失败';
    }
    if (controller.jobs.isEmpty) {
      return '暂无任务';
    }
    return '${controller.jobs.length} 个任务';
  }

  Widget _buildContent(BuildContext context) {
    if (controller.isLoadingJobs && controller.jobs.isEmpty) {
      return Container(
        key: const Key('activity-jobs-loading'),
        width: double.infinity,
        padding: EdgeInsets.all(context.appSpacing.lg),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (controller.jobErrorMessage != null && controller.jobs.isEmpty) {
      return Container(
        key: const Key('activity-jobs-error'),
        width: double.infinity,
        padding: EdgeInsets.all(context.appSpacing.lg),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppEmptyState(message: controller.jobErrorMessage!),
            SizedBox(height: context.appSpacing.md),
            AppButton(
              key: const Key('activity-jobs-retry-button'),
              label: '重试',
              size: AppButtonSize.small,
              onPressed: controller.refreshJobs,
            ),
          ],
        ),
      );
    }

    if (controller.jobs.isEmpty) {
      return const AppEmptyState(message: '暂无可执行任务');
    }

    return Column(
      children: [
        for (var index = 0; index < controller.jobs.length; index++) ...[
          _ExecutableJobCard(
            job: controller.jobs[index],
            dateFormat: widget.dateFormat,
            isTriggering: controller.isTriggeringJob(
              controller.jobs[index].taskKey,
            ),
            onTrigger: () => widget.onTriggerJob(controller.jobs[index]),
          ),
          if (index != controller.jobs.length - 1)
            SizedBox(height: context.appSpacing.md),
        ],
        if (controller.jobErrorMessage != null) ...[
          SizedBox(height: context.appSpacing.md),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingJobs,
            errorMessage: controller.jobErrorMessage,
            onRetry: controller.refreshJobs,
          ),
        ],
      ],
    );
  }
}

class _ExecutableJobsHeader extends StatelessWidget {
  const _ExecutableJobsHeader({
    required this.isExpanded,
    required this.summary,
    required this.onToggle,
  });

  final bool isExpanded;
  final String summary;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('activity-jobs-toggle'),
        borderRadius: context.appRadius.mdBorder,
        onTap: onToggle,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.lg,
            vertical: context.appSpacing.md,
          ),
          decoration: BoxDecoration(
            color: context.appColors.surfaceCard,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '可执行任务',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppBadge(label: summary, tone: AppBadgeTone.neutral),
              SizedBox(width: context.appSpacing.sm),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: context.appComponentTokens.iconSizeMd,
                color: context.appTextPalette.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutableJobCard extends StatelessWidget {
  const _ExecutableJobCard({
    required this.job,
    required this.dateFormat,
    required this.isTriggering,
    required this.onTrigger,
  });

  final JobMetadataDto job;
  final DateFormat dateFormat;
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final lastTaskRun = job.lastTaskRun;
    final canTrigger = job.manualTriggerAllowed && !isTriggering;

    return Container(
      key: Key('activity-job-${job.taskKey}'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.cliHelp.isEmpty ? job.taskKey : job.cliHelp,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: context.appSpacing.sm),
                Wrap(
                  spacing: context.appSpacing.sm,
                  runSpacing: context.appSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      label: job.cronExpr.isEmpty ? '未配置定时' : job.cronExpr,
                      tone: AppBadgeTone.neutral,
                    ),
                    if (lastTaskRun != null)
                      AppBadge(
                        label: _labelForTaskState(lastTaskRun.state),
                        tone: _taskStateTone(lastTaskRun.state),
                      ),
                    Text(
                      lastTaskRun == null
                          ? '暂无运行记录'
                          : '最近运行：${_taskTimeSummary(lastTaskRun, dateFormat)}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          AppButton(
            key: Key('activity-job-trigger-${job.taskKey}'),
            label:
                job.manualTriggerAllowed
                    ? (isTriggering ? '提交中' : '立即执行')
                    : '不可手动执行',
            size: AppButtonSize.small,
            variant: AppButtonVariant.primary,
            isLoading: isTriggering,
            onPressed: canTrigger ? onTrigger : null,
          ),
        ],
      ),
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
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
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
          width: layoutTokens.filterFieldWidthLg,
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
          width: layoutTokens.filterFieldWidthMd,
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
          width: layoutTokens.filterFieldWidthXl,
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
    required this.notification,
    required this.dateFormat,
  });

  final ActivityNotificationDto notification;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
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
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        notification.content,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.md),
            Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppBadge(
                  label: _labelForNotificationCategory(notification.category),
                  tone: _notificationCategoryTone(notification.category),
                ),
                Text(
                  _formatDate(notification.createdAt, dateFormat),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
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
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    if ((taskRun.progressText ?? '').trim().isNotEmpty) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        taskRun.progressText!,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.appSpacing.md),
              AppBadge(
                label: _labelForTaskState(taskRun.state),
                tone: _taskStateTone(taskRun.state),
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
              AppBadge(
                label: _labelForTriggerType(taskRun.triggerType),
                tone: AppBadgeTone.neutral,
              ),
              Text(
                _taskTimeSummary(taskRun, dateFormat),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
          if ((taskRun.displaySummary ?? '').trim().isNotEmpty) ...[
            SizedBox(height: context.appSpacing.md),
            Text(
              taskRun.displaySummary!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
        ],
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

AppBadgeTone _notificationCategoryTone(String category) {
  return switch (category) {
    'error' => AppBadgeTone.error,
    'warning' => AppBadgeTone.warning,
    'info' => AppBadgeTone.primary,
    _ => AppBadgeTone.neutral,
  };
}

AppBadgeTone _taskStateTone(String state) {
  return switch (state) {
    'failed' => AppBadgeTone.error,
    'completed' => AppBadgeTone.success,
    'running' => AppBadgeTone.primary,
    'pending' => AppBadgeTone.warning,
    _ => AppBadgeTone.neutral,
  };
}

String _labelForNotificationCategory(String value) {
  return switch (value) {
    'info' => '信息',
    'warning' => '警告',
    'error' => '错误',
    'reminder' => '提醒',
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
