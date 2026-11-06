import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/job_params_dialog.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_executable_jobs_section.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_section.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_filter_bar.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

class DesktopActivityPage extends ConsumerStatefulWidget {
  const DesktopActivityPage({super.key});

  @override
  ConsumerState<DesktopActivityPage> createState() =>
      _DesktopActivityPageState();
}

/// 任务中心：概览（活动任务、可执行任务）与任务历史两个 Tab。
///
/// 「任务历史」默认只列操作类记录（排除定时触发的例行成功）；按任务或触发
/// 来源筛选时切到全量运行记录。
class _DesktopActivityPageState extends ConsumerState<DesktopActivityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _overviewScrollController;
  late final ScrollController _historyScrollController;
  bool? _isPageVisible;

  ActivityCenter get _controller => ref.read(activityCenterProvider.notifier);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _overviewScrollController = ScrollController();
    _historyScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.of(context);
    if (_isPageVisible == isVisible) return;
    _isPageVisible = isVisible;

    // didChangeDependencies 属于 widget 构建阶段；延后 provider 写入，避免
    // TickerMode 切换时同步更新轮询状态而触发 build 期间修改 provider。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPageVisible != isVisible) return;
      if (isVisible) {
        unawaited(_controller.resumePolling());
      } else {
        _controller.pausePolling();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _overviewScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  Future<void> _triggerJob(JobMetadataDto job) async {
    final l10n = AppLocalizations.of(context);
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
        showToast(l10n.activityJobSubmitted, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException &&
          error.statusCode == 409 &&
          error.error?.code == 'task_conflict') {
        showToast(l10n.activityJobAlreadyRunning, tone: AppToastTone.info);
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.activityJobSubmitFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Widget _buildOverviewTab(
    BuildContext context, {
    required bool isInitialLoading,
    required String? initialErrorMessage,
  }) {
    return AppKeepAlive(
      child: CustomScrollView(
        key: const Key('activity-overview-scroll'),
        controller: _overviewScrollController,
        slivers: [
          if (initialErrorMessage != null)
            SliverToBoxAdapter(
              child: _InitialErrorState(
                message: initialErrorMessage,
                onRetry: _controller.reloadAll,
              ),
            )
          else ...[
            if (isInitialLoading)
              AppSkeletonizer.sliver(
                enabled: true,
                child: _ActiveRunsSection(
                  runs: taskRunPlaceholders(
                    count: 2,
                    l10n: AppLocalizations.of(context),
                  ),
                  highlightedId: null,
                ),
              )
            else
              const _ActiveRunsSliver(),
            ActivityExecutableJobsSliver(
              isInitialLoading: isInitialLoading,
              onTriggerJob: _triggerJob,
            ),
          ],
          ...bottomSafeAreaSliver(context),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context, {
    required bool isInitialLoading,
    required String? initialErrorMessage,
    required FilterUpdateState filterUpdate,
    required bool hasTaskItems,
  }) {
    return AppKeepAlive(
      child: AppFixedHeaderLayout(
        header: _buildHistoryHeader(
          context,
          filterUpdate: filterUpdate,
          hasTaskItems: hasTaskItems,
        ),
        child: AppFilterResultLoadingOverlay(
          isLoading: filterUpdate.isLoading,
          hasPreviousItems: hasTaskItems,
          child: AppPagedLoadMoreScope(
            canLoadMore: () =>
                ref.read(activityCenterProvider).value?.canAutoLoadMoreTasks ??
                false,
            onLoadMore: _controller.loadMoreTasks,
            child: CustomScrollView(
              key: const Key('activity-history-scroll'),
              controller: _historyScrollController,
              slivers: [
                ..._buildHistorySlivers(
                  context,
                  isInitialLoading: isInitialLoading,
                  initialErrorMessage: initialErrorMessage,
                ),
                ...bottomSafeAreaSliver(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(
    BuildContext context, {
    required FilterUpdateState filterUpdate,
    required bool hasTaskItems,
  }) {
    return Padding(
      key: const Key('activity-history-filter-header'),
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivityTaskFilterBar(controller: _controller),
          AppFilterUpdateBar(
            state: filterUpdate,
            hasPreviousItems: hasTaskItems,
            onRetry: _controller.refreshTaskHistory,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistorySlivers(
    BuildContext context, {
    required bool isInitialLoading,
    required String? initialErrorMessage,
  }) {
    if (isInitialLoading) {
      return <Widget>[
        AppSkeletonizer.sliver(
          enabled: true,
          child: _HistoryRunsList(
            runs: taskRunPlaceholders(
              count: 3,
              finished: false,
              l10n: AppLocalizations.of(context),
            ),
            highlightedId: null,
          ),
        ),
      ];
    }
    if (initialErrorMessage != null) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _InitialErrorState(
            message: initialErrorMessage,
            onRetry: _controller.reloadAll,
          ),
        ),
      ];
    }
    return <Widget>[
      const _HistoryRunsSliver(),
      // 运行记录页脚常驻：loading / 失败时显示行，空闲只留上下间距
      // （空列表 + 筛选失败时不占位，与原逻辑一致）。
      PagedLoadMoreFooterSliver(
        topSpacing: PagedFooterSpacing.lg,
        bottomSpacing: PagedFooterSpacing.xl,
        padWhenIdle: true,
        watchFooter: (ref) => ref.watch(
          activityCenterProvider.select((v) {
            final state = v.value;
            final runs = state?.taskRuns ?? const <TaskRunDto>[];
            if (runs.isEmpty && (state?.taskFilterUpdate.hasFailed ?? false)) {
              return null;
            }
            return (
              isLoading: state?.isLoadingMoreTasks ?? false,
              errorMessage: state?.taskLoadMoreErrorMessage,
            );
          }),
        ),
        onLoadMore: (ref) => unawaited(
          ref.read(activityCenterProvider.notifier).loadMoreTasks(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅页面骨架所需的字段：活动任务、历史条目与翻页状态走各自 Tab 内的
    // 独立订阅，不重建整页（见 _ActiveRunsSliver / _HistoryRunsSliver /
    // PagedLoadMoreFooterSliver）。轮询无实质变化时 provider 本就不写回。
    final pageView = ref.watch(
      activityCenterProvider.select((asyncValue) {
        final state = asyncValue.value;
        return (
          taskFilter: state?.taskFilter ?? ActivityTaskFilterState.initial,
          taskFilterUpdate:
              state?.taskFilterUpdate ?? const FilterUpdateState.idle(),
          hasTaskItems: state?.taskRuns.isNotEmpty ?? false,
          // 首帧是 AsyncLoading：必须让它进入快照，否则 select 前后等值，
          // 页面不会在加载完成后重建、骨架分支会永久留在树上。
          isInitialLoading:
              asyncValue.isLoading || (state?.isInitialLoading ?? false),
          initialErrorMessage: state?.initialErrorMessage,
        );
      }),
    );
    ref.listen(
      activityCenterProvider.select((value) => value.value?.taskFilter),
      (previous, next) {
        if (previous != null &&
            next != null &&
            previous != next &&
            _historyScrollController.hasClients) {
          _historyScrollController.jumpTo(0);
        }
      },
    );
    final l10n = AppLocalizations.of(context);
    return AppPageRefreshScope(
      onRefresh: _controller.refreshAll,
      child: Column(
        key: const Key('desktop-activity-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTabBar(
            key: const Key('activity-tabs'),
            controller: _tabController,
            tabs: [
              Tab(
                key: const Key('activity-tab-overview'),
                text: l10n.activityTabOverview,
              ),
              Tab(
                key: const Key('activity-tab-history'),
                text: l10n.activityTabHistory,
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(
            child: TabBarView(
              key: const Key('activity-tab-view'),
              controller: _tabController,
              children: [
                _buildOverviewTab(
                  context,
                  isInitialLoading: pageView.isInitialLoading,
                  initialErrorMessage: pageView.initialErrorMessage,
                ),
                _buildHistoryTab(
                  context,
                  isInitialLoading: pageView.isInitialLoading,
                  initialErrorMessage: pageView.initialErrorMessage,
                  filterUpdate: pageView.taskFilterUpdate,
                  hasTaskItems: pageView.hasTaskItems,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 活动任务区：独立订阅进行中任务与高亮 id。
///
/// 进度 tick 只重建本区，历史列表不受牵连。
class _ActiveRunsSliver extends ConsumerWidget {
  const _ActiveRunsSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      activityCenterProvider.select(
        (asyncValue) => (
          runs: asyncValue.value?.activeTaskRuns ?? const <TaskRunDto>[],
          highlightedId: asyncValue.value?.highlightedTaskRunId,
        ),
      ),
    );
    if (view.runs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return _ActiveRunsSection(
      runs: view.runs,
      highlightedId: view.highlightedId,
    );
  }
}

/// 活动任务区（纯展示 sliver）：真实列表与首屏骨架共用同一套行渲染。
class _ActiveRunsSection extends StatelessWidget {
  const _ActiveRunsSection({required this.runs, required this.highlightedId});

  final List<TaskRunDto> runs;
  final int? highlightedId;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final spacing = context.appSpacing;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivitySection(
            title: AppLocalizations.of(context).activityActiveTasks,
            child: Column(
              children: [
                for (var index = 0; index < runs.length; index++) ...[
                  RepaintBoundary(
                    child: ActivityTaskRunCard(
                      taskRun: runs[index],
                      highlighted: highlightedId == runs[index].id,
                    ),
                  ),
                  if (index != runs.length - 1) SizedBox(height: spacing.md),
                ],
              ],
            ),
          ),
          SizedBox(height: spacing.xl),
        ],
      ),
    );
  }
}

/// 运行记录列表：独立订阅历史条目与高亮 id。
///
/// 活动进度 tick 与翻页状态翻转不重建本列表（条目追加时正常重建）。
class _HistoryRunsSliver extends ConsumerWidget {
  const _HistoryRunsSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      activityCenterProvider.select((asyncValue) {
        final state = asyncValue.value;
        return (
          runs: state?.taskRuns ?? const <TaskRunDto>[],
          highlightedId: state?.highlightedTaskRunId,
          filterFailed: state?.taskFilterUpdate.hasFailed ?? false,
        );
      }),
    );
    final historyRuns = view.runs;
    if (historyRuns.isEmpty && view.filterFailed) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (historyRuns.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: AppLocalizations.of(context).activityEmptyTasksFiltered,
        ),
      );
    }
    return _HistoryRunsList(
      runs: historyRuns,
      highlightedId: view.highlightedId,
    );
  }
}

/// 运行记录条目列表（纯展示）：真实列表与首屏骨架共用同一套行渲染，
/// 避免骨架路径另写一份渲染逻辑后与真实列表漂移。
class _HistoryRunsList extends StatelessWidget {
  const _HistoryRunsList({required this.runs, required this.highlightedId});

  final List<TaskRunDto> runs;
  final int? highlightedId;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = runs[index];
          final isLast = index == runs.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : context.appSpacing.md,
            ),
            child: RepaintBoundary(
              child: ActivityTaskRunCard(
                taskRun: item,
                highlighted: highlightedId == item.id,
              ),
            ),
          );
        },
        childCount: runs.length,
        // 行未申请 keep-alive；AutomaticKeepAlive 只增加元素开销。
        addAutomaticKeepAlives: false,
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
    final l10n = AppLocalizations.of(context);
    return ActivitySection(
      title: l10n.activityCenterTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppEmptyState(message: message),
          SizedBox(height: context.appSpacing.lg),
          AppButton(label: l10n.commonRetry, onPressed: () => onRetry()),
        ],
      ),
    );
  }
}
