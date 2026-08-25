import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/job_params_dialog.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_pane.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

class DesktopActivityPage extends ConsumerStatefulWidget {
  const DesktopActivityPage({super.key, this.initialDownloadMovieNumber});

  /// 打开后直接定位到「下载任务」tab 并按该番号过滤；null（普通入口）行为不变。
  final String? initialDownloadMovieNumber;

  @override
  ConsumerState<DesktopActivityPage> createState() =>
      _DesktopActivityPageState();
}

class _DesktopActivityPageState extends ConsumerState<DesktopActivityPage>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreTriggerOffset = 300;

  late final TabController _tabController;
  late final ScrollController _pageScrollController;
  bool _isViewportWorkScheduled = false;
  ActivityTab? _lastActiveTab = ActivityTab.tasks;
  bool _hasOpenedDownloadTasks = false;

  ActivityCenter get _controller => ref.read(activityCenterProvider.notifier);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _pageScrollController = ScrollController()..addListener(_handlePageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleViewportWork();
      }
    });
    // 订阅卡片跳转进来的下载意图：等首帧后统一走同一路径（切 tab + 应用筛选），
    // 避免与 activity provider 的 bootstrap 初始化互相踩。
    if (widget.initialDownloadMovieNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_applyInitialDownloadIntent());
        }
      });
    }
  }

  /// 消费「打开即看某番号下载任务」的意图：先应用筛选再切 tab。
  Future<void> _applyInitialDownloadIntent() async {
    final movieNumber = widget.initialDownloadMovieNumber?.trim();
    if (movieNumber == null || movieNumber.isEmpty) {
      return;
    }
    await ref
        .read(downloadTaskCenterProvider.notifier)
        .applyFilter(
          DownloadTaskFilterState(
            // 用 all 而不是默认 downloading：订阅的导入失败任务可能已经下载完成，
            // 按 downloading 过滤会把它们滤掉。
            stateFilter: DownloadTaskStateFilter.all,
            search: movieNumber,
          ),
        );
    if (!mounted) {
      return;
    }
    _controller.setActiveTab(ActivityTab.downloadTasks);
  }

  @override
  void dispose() {
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
    }
  }

  void _syncTabSelection(ActivityTab activeTab) {
    if (_tabController.index != activeTab.index) {
      _tabController.animateTo(activeTab.index);
    }
    _handleActiveTabDiff(activeTab);
  }

  /// 收敛 tab 切换的副作用：手势切 tab、程序化 setActiveTab（如 triggerJob）
  /// 都过这条路径。切进下载任务时开始轮询，切走后停止轮询。
  void _handleActiveTabDiff(ActivityTab nextTab) {
    if (nextTab == _lastActiveTab) {
      return;
    }
    final previousTab = _lastActiveTab;
    _lastActiveTab = nextTab;

    if (nextTab == ActivityTab.downloadTasks) {
      if (!_hasOpenedDownloadTasks) {
        setState(() {
          _hasOpenedDownloadTasks = true;
        });
      }
      unawaited(ref.read(downloadTaskCenterProvider.notifier).startPolling());
    } else if (previousTab == ActivityTab.downloadTasks) {
      ref.read(downloadTaskCenterProvider.notifier).stopPolling();
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
    final activity = ref.read(activityCenterProvider).value;
    if (!_pageScrollController.hasClients ||
        activity == null ||
        activity.isInitialLoading ||
        activity.initialErrorMessage != null) {
      return;
    }
    if (!_shouldAutoLoadMoreForViewport()) {
      return;
    }

    switch (activity.activeTab) {
      case ActivityTab.tasks:
        if (activity.hasMoreTasks &&
            !activity.isLoadingMoreTasks &&
            activity.taskLoadMoreErrorMessage == null) {
          unawaited(_controller.loadMoreTasks());
        }
        break;
      case ActivityTab.downloadTasks:
        final downloadCenter = ref.read(downloadTaskCenterProvider).value;
        if (downloadCenter != null &&
            downloadCenter.paged.hasMore &&
            !downloadCenter.paged.isLoadingMore &&
            downloadCenter.paged.loadMoreErrorMessage == null) {
          unawaited(ref.read(downloadTaskCenterProvider.notifier).loadMore());
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
      Map<String, dynamic>? params;
      if (job.paramsSchema != null) {
        params = await showJobParamsDialog(context, job: job);
        if (!mounted || params == null) {
          return;
        }
      }
      await _controller.triggerJob(job.taskKey, params: params);
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

  Future<void> _openExecutableJobsDialog(BuildContext context) async {
    await showAppAdaptiveModal<void>(
      context: context,
      modalKey: const Key('activity-executable-jobs-dialog'),
      desktopWidth: context.appLayoutTokens.dialogWidthMd,
      builder: (_) => _ExecutableJobsDialog(onTriggerJob: _triggerJob),
    );
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
      ActivityTab.tasks => _buildTaskSlivers(context),
      ActivityTab.downloadTasks => buildDownloadTaskSlivers(
        context: context,
        ref: ref,
      ),
    };
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
              onOpen: () => unawaited(_openExecutableJobsDialog(context)),
            ),
            SizedBox(height: context.appSpacing.xl),
            _ActivitySection(
              title: '任务历史',
              titleStyle: titleStyle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TaskFilterBar(controller: _controller),
                  AppFilterUpdateBar(
                    state: _controller.taskFilterUpdate,
                    hasPreviousItems: _controller.taskRuns.isNotEmpty,
                    onRetry: _controller.refreshTaskHistory,
                  ),
                ],
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
          ],
        ),
      ),
    ];

    if (_controller.taskRuns.isEmpty &&
        _controller.taskFilterUpdate.hasFailed) {
      return slivers;
    }
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

  Future<void> _refreshActiveTab() async {
    switch (_controller.activeTab) {
      case ActivityTab.tasks:
        await _controller.refreshTaskHistory();
      case ActivityTab.downloadTasks:
        await ref.read(downloadTaskCenterProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityCenterProvider);
    final activeTab = activityAsync.value?.activeTab ?? ActivityTab.tasks;
    if (_hasOpenedDownloadTasks || activeTab == ActivityTab.downloadTasks) {
      ref.watch(downloadTaskCenterProvider);
    }
    ref.listen<ActivityTab>(
      activityCenterProvider.select(
        (value) => value.value?.activeTab ?? ActivityTab.tasks,
      ),
      (_, next) => _syncTabSelection(next),
    );
    ref.listen(
      activityCenterProvider.select((value) => value.value?.taskFilter),
      (previous, next) {
        if (previous != null &&
            next != null &&
            previous != next &&
            activeTab == ActivityTab.tasks &&
            _pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
      },
    );
    if (_hasOpenedDownloadTasks || activeTab == ActivityTab.downloadTasks) {
      ref.listen(
        downloadTaskCenterProvider.select((value) => value.value?.filter),
        (previous, next) {
          if (previous != null &&
              next != null &&
              previous != next &&
              activeTab == ActivityTab.downloadTasks &&
              _pageScrollController.hasClients) {
            _pageScrollController.jumpTo(0);
          }
        },
      );
    }
    ref.listen<AsyncValue<ActivityCenterState>>(
      activityCenterProvider,
      (_, __) => _handleControllerChanged(),
    );
    if (_hasOpenedDownloadTasks || activeTab == ActivityTab.downloadTasks) {
      ref.listen<AsyncValue<DownloadTaskCenterState>>(
        downloadTaskCenterProvider,
        (_, __) => _handleControllerChanged(),
      );
    }
    return AppPageRefreshScope(
      onRefresh: _refreshActiveTab,
      child: Stack(
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
                        Tab(key: Key('activity-tab-tasks'), text: '后台任务'),
                        Tab(
                          key: Key('activity-tab-download-tasks'),
                          text: '下载任务',
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
        ],
      ),
    );
  }
}

class _InitialLoadingState extends StatelessWidget {
  const _InitialLoadingState();

  @override
  Widget build(BuildContext context) {
    return _ActivitySection(
      title: '任务中心',
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
      title: '任务中心',
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
      ActivityConnectionState.connecting => colors.surfaceMuted,
      ActivityConnectionState.polling => colors.selectionSurface,
    };
    final foregroundColor = switch (state) {
      ActivityConnectionState.connecting => context.appTextPalette.secondary,
      ActivityConnectionState.polling => context.appTextPalette.accent,
    };
    final icon = switch (state) {
      ActivityConnectionState.connecting => Icons.sync_rounded,
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

class _ExecutableJobsSection extends StatelessWidget {
  const _ExecutableJobsSection({
    required this.controller,
    required this.onOpen,
  });

  final ActivityCenter controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _ExecutableJobsHeader(summary: _summaryText, onOpen: onOpen);
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
}

class _ExecutableJobsHeader extends StatelessWidget {
  const _ExecutableJobsHeader({required this.summary, required this.onOpen});

  final String summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: '可执行任务',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBadge(label: summary, tone: AppBadgeTone.neutral),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('activity-jobs-toggle'),
            label: '查看任务',
            icon: const Icon(Icons.list_alt_rounded),
            size: AppButtonSize.small,
            onPressed: onOpen,
          ),
        ],
      ),
      child: Text(
        '手动触发已注册的后台任务，执行状态会在任务中心实时更新。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      ),
    );
  }
}

class _ExecutableJobCard extends StatelessWidget {
  const _ExecutableJobCard({
    required this.job,
    required this.isTriggering,
    required this.onTrigger,
  });

  final JobMetadataDto job;
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final lastTaskRun = job.lastTaskRun;
    final canTrigger = job.manualTriggerAllowed && !isTriggering;

    return AppContentCard(
      key: Key('activity-job-${job.taskKey}'),
      padding: EdgeInsets.all(context.appSpacing.lg),
      title: job.cliHelp.isEmpty ? job.taskKey : job.cliHelp,
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
      headerBottomSpacing: context.appSpacing.sm,
      headerTrailing: AppButton(
        key: Key('activity-job-trigger-${job.taskKey}'),
        label: job.manualTriggerAllowed
            ? (isTriggering
                  ? '提交中'
                  : job.paramsSchema == null
                  ? '立即执行'
                  : '填写参数')
            : '不可手动执行',
        size: AppButtonSize.small,
        variant: AppButtonVariant.primary,
        isLoading: isTriggering,
        onPressed: canTrigger ? onTrigger : null,
      ),
      child: Wrap(
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
          if (job.paramsSchema != null)
            const AppBadge(label: '需填写参数', tone: AppBadgeTone.info),
          Text(
            lastTaskRun == null
                ? '暂无运行记录'
                : '最近运行：${_taskTimeSummary(lastTaskRun)}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutableJobsDialog extends ConsumerWidget {
  const _ExecutableJobsDialog({required this.onTriggerJob});

  final ValueChanged<JobMetadataDto> onTriggerJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityCenterProvider);
    final controller = ref.read(activityCenterProvider.notifier);
    final body = activity.when(
      loading: () => const _ExecutableJobsDialogLoadingBody(),
      error: (error, _) => AppEmptyState(
        key: const Key('activity-jobs-error'),
        message: apiErrorMessage(error, fallback: '可执行任务加载失败，请重试'),
        onRetry: controller.reloadAll,
        retryKey: const Key('activity-jobs-retry-button'),
      ),
      data: (state) => _ExecutableJobsDialogContent(
        state: state,
        controller: controller,
        onTriggerJob: onTriggerJob,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ExecutableJobsDialogHeader(),
        SizedBox(height: context.appSpacing.lg),
        body,
      ],
    );
  }
}

class _ExecutableJobsDialogContent extends StatelessWidget {
  const _ExecutableJobsDialogContent({
    required this.state,
    required this.controller,
    required this.onTriggerJob,
  });

  final ActivityCenterState state;
  final ActivityCenter controller;
  final ValueChanged<JobMetadataDto> onTriggerJob;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final jobs = state.jobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isLoadingJobs && jobs.isEmpty)
          const _ExecutableJobsDialogLoadingBody()
        else if (state.jobErrorMessage != null && jobs.isEmpty)
          AppEmptyState(
            key: const Key('activity-jobs-error'),
            message: state.jobErrorMessage!,
            onRetry: controller.refreshJobs,
            retryKey: const Key('activity-jobs-retry-button'),
          )
        else if (jobs.isEmpty)
          const AppEmptyState(message: '暂无可执行任务')
        else ...[
          if (state.isLoadingJobs) ...[
            Row(
              children: [
                const AppInlineSpinner(),
                SizedBox(width: spacing.sm),
                Text(
                  '正在刷新任务列表',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            child: ListView.separated(
              key: const Key('activity-executable-jobs-list'),
              shrinkWrap: true,
              itemCount: jobs.length,
              separatorBuilder: (_, __) => SizedBox(height: spacing.md),
              itemBuilder: (_, index) {
                final job = jobs[index];
                return _ExecutableJobCard(
                  job: job,
                  isTriggering: controller.isTriggeringJob(job.taskKey),
                  onTrigger: () => onTriggerJob(job),
                );
              },
            ),
          ),
          if (state.jobErrorMessage != null) ...[
            SizedBox(height: spacing.md),
            _ExecutableJobsRefreshError(
              message: state.jobErrorMessage!,
              onRetry: controller.refreshJobs,
            ),
          ],
        ],
      ],
    );
  }
}

class _ExecutableJobsDialogHeader extends StatelessWidget {
  const _ExecutableJobsDialogHeader();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.only(right: spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '可执行任务',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '选择一个任务手动执行，运行结果会回到后台任务列表。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutableJobsDialogLoadingBody extends StatelessWidget {
  const _ExecutableJobsDialogLoadingBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxl),
      child: const Center(child: AppInlineSpinner()),
    );
  }
}

class _ExecutableJobsRefreshError extends StatelessWidget {
  const _ExecutableJobsRefreshError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.error,
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('activity-jobs-retry-button'),
          label: '重试',
          size: AppButtonSize.xSmall,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({required this.controller});

  final ActivityCenter controller;

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
    if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
      return _MobileTaskFilterEntry(controller: controller);
    }
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
            onChanged: (value) => controller.applyTaskFilter(
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
            onChanged: (value) => controller.applyTaskFilter(
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
            onChanged: (value) => controller.applyTaskFilter(
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
            onChanged: (value) => controller.applyTaskFilter(
              controller.taskFilter.copyWith(
                sort: value ?? ActivityTaskSort.startedAtDesc,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileTaskFilterEntry extends StatelessWidget {
  const _MobileTaskFilterEntry({required this.controller});

  final ActivityCenter controller;

  @override
  Widget build(BuildContext context) {
    final filter = controller.taskFilter;
    final isSelected = filter != ActivityTaskFilterState.initial;
    return Row(
      children: [
        Expanded(
          child: Text(
            _taskFilterSummary(filter),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        AppButton(
          key: const Key('mobile-activity-task-filter-button'),
          label: isSelected ? '已筛选' : '筛选',
          icon: const Icon(Icons.tune_rounded),
          size: AppButtonSize.small,
          isSelected: isSelected,
          onPressed: () => _showMobileActivityTaskFilterDrawer(
            context,
            current: filter,
            knownTaskKeys: controller.knownTaskKeys,
            onChanged: (next) => unawaited(controller.applyTaskFilter(next)),
          ),
        ),
      ],
    );
  }
}

Future<void> _showMobileActivityTaskFilterDrawer(
  BuildContext context, {
  required ActivityTaskFilterState current,
  required List<String> knownTaskKeys,
  required ValueChanged<ActivityTaskFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-activity-task-filter-drawer'),
    maxHeightFactor: 0.68,
    builder: (_) => _MobileTaskFilterDrawerContent(
      current: current,
      knownTaskKeys: knownTaskKeys,
      onChanged: onChanged,
    ),
  );
}

class _MobileTaskFilterDrawerContent extends StatefulWidget {
  const _MobileTaskFilterDrawerContent({
    required this.current,
    required this.knownTaskKeys,
    required this.onChanged,
  });

  final ActivityTaskFilterState current;
  final List<String> knownTaskKeys;
  final ValueChanged<ActivityTaskFilterState> onChanged;

  @override
  State<_MobileTaskFilterDrawerContent> createState() =>
      _MobileTaskFilterDrawerContentState();
}

class _MobileTaskFilterDrawerContentState
    extends State<_MobileTaskFilterDrawerContent> {
  late ActivityTaskFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  void _apply(ActivityTaskFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-activity-task-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local == ActivityTaskFilterState.initial,
        onReset: () => _apply(ActivityTaskFilterState.initial),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '筛选任务历史',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.lg),
          AppSelectField<String?>(
            key: const Key('mobile-activity-task-state-filter'),
            label: '任务状态',
            value: _local.state,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(value: null, child: Text('全部状态')),
              ..._TaskFilterBar._states.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForTaskState(value)),
                ),
              ),
            ],
            onChanged: (value) => _apply(_local.copyWith(state: value)),
          ),
          SizedBox(height: context.appSpacing.md),
          AppSelectField<String?>(
            key: const Key('mobile-activity-task-key-filter'),
            label: '任务类型',
            value: _local.taskKey,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('全部任务类型'),
              ),
              ...widget.knownTaskKeys.map(
                (value) =>
                    DropdownMenuItem<String?>(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => _apply(_local.copyWith(taskKey: value)),
          ),
          SizedBox(height: context.appSpacing.md),
          AppSelectField<String?>(
            key: const Key('mobile-activity-task-trigger-filter'),
            label: '触发来源',
            value: _local.triggerType,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('全部触发来源'),
              ),
              ..._TaskFilterBar._triggerTypes.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(_labelForTriggerType(value)),
                ),
              ),
            ],
            onChanged: (value) => _apply(_local.copyWith(triggerType: value)),
          ),
          SizedBox(height: context.appSpacing.md),
          AppSelectField<ActivityTaskSort>(
            key: const Key('mobile-activity-task-sort-filter'),
            label: '排序方式',
            value: _local.sort,
            items: ActivityTaskSort.values
                .map(
                  (value) => DropdownMenuItem<ActivityTaskSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => _apply(
              _local.copyWith(sort: value ?? ActivityTaskSort.startedAtDesc),
            ),
          ),
        ],
      ),
    );
  }
}

String _taskFilterSummary(ActivityTaskFilterState filter) {
  final values = <String>[];
  if (filter.state != null) values.add(_labelForTaskState(filter.state!));
  if (filter.taskKey != null) values.add(filter.taskKey!);
  if (filter.triggerType != null) {
    values.add(_labelForTriggerType(filter.triggerType!));
  }
  values.add(filter.sort.label);
  return values.join(' · ');
}

class _TaskRunCard extends StatelessWidget {
  const _TaskRunCard({required this.taskRun, required this.highlighted});

  final TaskRunDto taskRun;
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
          color: highlighted
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
            // 仅在有确定进度时渲染带动画的进度条；否则用静态灰条占位。
            // value 为 null 时 LinearProgressIndicator 是无限循环动画，
            // 会让 GPU 持续光栅化（核显吃满）。
            if (taskRun.hasDeterminateProgress)
              ClipRRect(
                borderRadius: context.appRadius.pillBorder,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progressValue,
                  backgroundColor: colors.surfaceMuted,
                ),
              )
            else
              ClipRRect(
                borderRadius: context.appRadius.pillBorder,
                child: Container(height: 6, color: colors.surfaceMuted),
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
                _taskTimeSummary(taskRun),
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

String _taskTimeSummary(TaskRunDto item) {
  if (item.finishedAt != null) {
    return '完成于 ${formatUpdatedAtLabel(item.finishedAt) ?? '时间未知'}';
  }
  if (item.startedAt != null) {
    return '开始于 ${formatUpdatedAtLabel(item.startedAt) ?? '时间未知'}';
  }
  return '创建于 ${formatUpdatedAtLabel(item.createdAt) ?? '时间未知'}';
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
