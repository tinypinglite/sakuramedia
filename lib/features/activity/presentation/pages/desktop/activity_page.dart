import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/job_params_dialog.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_executable_jobs_card.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_jobs_dialog.dart';
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
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';

class DesktopActivityPage extends ConsumerStatefulWidget {
  const DesktopActivityPage({super.key});

  @override
  ConsumerState<DesktopActivityPage> createState() =>
      _DesktopActivityPageState();
}

/// 任务中心：活动任务、可执行任务摘要与最近操作。
///
/// 默认「最近操作」只列操作类记录（排除定时触发的例行成功）；按任务或触发
/// 来源筛选时切到全量运行记录。
class _DesktopActivityPageState extends ConsumerState<DesktopActivityPage> {
  late final ScrollController _pageScrollController;
  bool? _isPageVisible;

  ActivityCenter get _controller => ref.read(activityCenterProvider.notifier);

  @override
  void initState() {
    super.initState();
    _pageScrollController = ScrollController();
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
    _pageScrollController.dispose();
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
        showToast(l10n.activityJobSubmitted);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException &&
          error.statusCode == 409 &&
          error.error?.code == 'task_conflict') {
        showToast(l10n.activityJobAlreadyRunning);
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.activityJobSubmitFailed,
          l10n: l10n,
        ),
      );
    }
  }

  Future<void> _openExecutableJobsDialog(BuildContext context) async {
    unawaited(_controller.refreshJobs());
    await showActivityJobsDialog(context, onTriggerJob: _triggerJob);
  }

  List<Widget> _buildTaskSlivers(
    BuildContext context, {
    required bool isInitialLoading,
    required String? initialErrorMessage,
    required ActivityTaskFilterState filter,
    required FilterUpdateState filterUpdate,
    required bool hasTaskItems,
  }) {
    if (isInitialLoading) {
      // loading 用占位任务渲染真实任务卡与历史列表，由 [AppSkeletonizer] 灰化；
      // 复用与真实列表同一套 section/list 组件，避免两套渲染器各自漂移。
      return <Widget>[
        AppSkeletonizer.sliver(
          enabled: true,
          child: _ActiveRunsSection(
            runs: taskRunPlaceholders(
              count: 2,
              l10n: AppLocalizations.of(context),
            ),
            highlightedId: null,
          ),
        ),
        AppSkeletonizer.sliver(
          enabled: true,
          child: _buildOperationsHeader(
            context,
            filter: filter,
            filterUpdate: filterUpdate,
            hasTaskItems: hasTaskItems,
          ),
        ),
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
    // 各段独立订阅：活动进度 tick 只重建活动区，翻页只重建页脚，
    // 历史列表不受两者牵连（见 _ActiveRunsSliver / _HistoryRunsSliver /
    // PagedLoadMoreFooterSliver）。静态头（可执行任务卡 + 标题 + 筛选）跟随父级重建。
    return <Widget>[
      _ActiveRunsSliver(),
      _ExecutableJobsSliver(
        onOpen: () => unawaited(_openExecutableJobsDialog(context)),
      ),
      _buildOperationsHeader(
        context,
        filter: filter,
        filterUpdate: filterUpdate,
        hasTaskItems: hasTaskItems,
      ),
      _HistoryRunsSliver(),
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

  /// 「最近操作 / 运行记录」静态头：标题 + 筛选条 + 筛选同步条。
  ///
  /// 只读低频字段，跟随父级重建；活动区 / 任务卡 / 历史 / 页脚独立订阅。
  Widget _buildOperationsHeader(
    BuildContext context, {
    required ActivityTaskFilterState filter,
    required FilterUpdateState filterUpdate,
    required bool hasTaskItems,
  }) {
    final l10n = AppLocalizations.of(context);
    final titleStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    );
    final showsFullRuns = filter.taskRunScope == ActivityTaskRunScope.all;
    return SliverToBoxAdapter(
      child: Column(
        key: const Key('activity-tasks-tab'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showsFullRuns
                ? l10n.activityRunRecords
                : l10n.activityRecentOperations,
            style: titleStyle,
          ),
          SizedBox(height: context.appSpacing.lg),
          ActivityTaskFilterBar(controller: _controller),
          AppFilterUpdateBar(
            state: filterUpdate,
            hasPreviousItems: hasTaskItems,
            onRetry: _controller.refreshTaskHistory,
          ),
          SizedBox(height: context.appSpacing.lg),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅页面骨架所需的字段：进行中任务进度、历史条目与翻页状态
    // 走独立订阅，不重建整页（见 _ActiveRunsSliver / _HistoryRunsSliver /
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
            _pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
      },
    );
    return AppPageRefreshScope(
      onRefresh: _controller.refreshAll,
      child: AppFilterResultLoadingOverlay(
        isLoading: pageView.taskFilterUpdate.isLoading,
        hasPreviousItems: pageView.hasTaskItems,
        child: AppPagedLoadMoreScope(
          canLoadMore: () =>
              ref.read(activityCenterProvider).value?.canAutoLoadMoreTasks ??
              false,
          onLoadMore: _controller.loadMoreTasks,
          child: CustomScrollView(
            controller: _pageScrollController,
            slivers: [
              // 连接横幅独立订阅：轮询状态变化只重建它，不重建整页。
              const _ConnectionBannerSliver(),
              ..._buildTaskSlivers(
                context,
                isInitialLoading: pageView.isInitialLoading,
                initialErrorMessage: pageView.initialErrorMessage,
                filter: pageView.taskFilter,
                filterUpdate: pageView.taskFilterUpdate,
                hasTaskItems: pageView.hasTaskItems,
              ),
              ...bottomSafeAreaSliver(context),
            ],
          ),
        ),
      ),
    );
  }
}

/// 连接横幅：独立订阅连接状态，轮询状态变化只重建它，不重建整页。
class _ConnectionBannerSliver extends ConsumerWidget {
  const _ConnectionBannerSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(
      activityCenterProvider.select(
        (asyncValue) => (
          state:
              asyncValue.value?.connectionState ??
              ActivityConnectionState.connecting,
          message: asyncValue.value?.connectionMessage,
        ),
      ),
    );
    return SliverToBoxAdapter(
      child: Column(
        key: const Key('desktop-activity-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.appSpacing.lg),
          ActivityConnectionBanner(
            state: banner.state,
            message: banner.message,
          ),
          SizedBox(height: context.appSpacing.xl),
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

/// 可执行任务摘要卡：点开后再查看任务明细。
class _ExecutableJobsSliver extends ConsumerWidget {
  const _ExecutableJobsSliver({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      activityCenterProvider.select(
        (asyncValue) => (
          jobs: asyncValue.value?.jobs ?? const <JobMetadataDto>[],
          isLoading: asyncValue.value?.isLoadingJobs ?? false,
          errorMessage: asyncValue.value?.jobErrorMessage,
        ),
      ),
    );
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xl),
        child: ActivityExecutableJobsCard(
          jobs: view.jobs,
          isLoading: view.isLoading,
          errorMessage: view.errorMessage,
          onOpen: onOpen,
        ),
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
