import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_pane.dart';
import 'package:sakuramedia/features/downloads/presentation/manual_download_dialog.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';

/// 独立下载任务页：桌面与移动端共用内容，仅刷新容器和页面壳不同。
class DesktopDownloadTasksPage extends ConsumerStatefulWidget {
  const DesktopDownloadTasksPage({super.key, this.initialDownloadMovieNumber});

  /// 从影片/订阅入口进入时按番号过滤；null 表示普通入口。
  final String? initialDownloadMovieNumber;

  @override
  ConsumerState<DesktopDownloadTasksPage> createState() =>
      _DesktopDownloadTasksPageState();
}

class _DesktopDownloadTasksPageState
    extends ConsumerState<DesktopDownloadTasksPage> {
  late final DownloadTaskCenter _controller;
  late final SelectionController<int> _selection;
  final ScrollController _scrollController = ScrollController();
  bool? _isPageVisible;
  bool _initialized = false;
  bool _pollingStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(downloadTaskCenterProvider.notifier);
    _selection = SelectionController<int>(
      orderedIds: () {
        final state = ref.read(downloadTaskCenterProvider).value;
        return state?.paged.items
                .map((row) => row.task.id)
                .toList(growable: false) ??
            const <int>[];
      },
    )..addListener(_handleSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_initialize());
      }
    });
  }

  void _handleSelectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await _applyInitialIntent(widget.initialDownloadMovieNumber);
    if (!mounted) return;
    _initialized = true;
    if (_isPageVisible != false) {
      _pollingStarted = true;
      unawaited(_controller.startPolling());
    }
  }

  Future<void> _applyInitialIntent(String? rawMovieNumber) async {
    final movieNumber = rawMovieNumber?.trim() ?? '';
    if (movieNumber.isEmpty) return;
    await _controller.applyFilter(
      DownloadTaskFilterState(
        // 用 all 而不是默认 downloading：订阅进来的任务可能已经下载完成，
        // 按 downloading 过滤会把它们滤掉。
        stateFilter: DownloadTaskStateFilter.all,
        search: movieNumber,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.of(context);
    if (_isPageVisible == isVisible) return;
    _isPageVisible = isVisible;

    // didChangeDependencies 属于构建阶段；延后 provider 写入，避免同步更新
    // 轮询状态时触发 build 期间修改 provider。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPageVisible != isVisible || !_initialized) {
        return;
      }
      if (isVisible) {
        if (_pollingStarted) {
          unawaited(_controller.resumePolling());
        } else {
          // 页面首次构建时不可见：初始化阶段没有启动轮询，可见后再补启动。
          _pollingStarted = true;
          unawaited(_controller.startPolling());
        }
      } else {
        _controller.pausePolling();
        _selection.exitSelection();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DesktopDownloadTasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNumber = oldWidget.initialDownloadMovieNumber?.trim() ?? '';
    final nextNumber = widget.initialDownloadMovieNumber?.trim() ?? '';
    if (oldNumber == nextNumber || nextNumber.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_applyInitialIntent(nextNumber));
      _scrollToTop();
    });
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    _controller.stopPolling();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _refresh() async {
    final error = await _controller.refresh();
    if (error != null && mounted) {
      showToast(error, tone: AppToastTone.error);
    }
  }

  /// 手动提交成功后让新任务可见：当前筛选会隐藏它时切到「全部」，
  /// 否则保留筛选就地刷新。
  Future<void> _openManualAdd() async {
    final result = await showManualDownloadDialog(context);
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    showToast(
      result.response.created
          ? l10n.downloadSubmittedToClient(result.clientName)
          : l10n.downloadTaskAlreadyExists,
      tone: result.response.created ? AppToastTone.success : AppToastTone.info,
    );

    final filter =
        ref.read(downloadTaskCenterProvider).value?.filter ??
        DownloadTaskFilterState.initial;
    if (_taskVisibleUnderFilter(result.response.task, filter)) {
      final error = await _controller.refresh();
      if (error != null && mounted) {
        showToast(error, tone: AppToastTone.error);
      }
    } else {
      await _controller.applyFilter(
        const DownloadTaskFilterState(stateFilter: DownloadTaskStateFilter.all),
      );
    }
    if (mounted) {
      _scrollToTop();
    }
  }

  bool _taskVisibleUnderFilter(
    DownloadTaskDto task,
    DownloadTaskFilterState filter,
  ) {
    final states = filter.stateFilter.apiValues;
    if (states != null && !states.contains(task.state)) {
      return false;
    }
    if (filter.clientId != null && filter.clientId != task.clientId) {
      return false;
    }
    final search = filter.normalizedSearch;
    if (search.isNotEmpty) {
      final movieNumber = task.movieNumber?.trim() ?? '';
      // 后端按 `DownloadTask.movie == movie_number.strip()` 精确过滤；这里
      // 不能再按不等长的子串判断，否则会误判为“可见”而跳过去「全部」的兜底，
      // 让刚创建的任务被筛选隐藏。
      if (movieNumber != search) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅覆盖层所需的两个字段：进度 tick 不重建整页。
    final view = ref.watch(
      downloadTaskCenterProvider.select((asyncValue) {
        final state = asyncValue.value;
        return (
          filterUpdate:
              state?.paged.filterUpdate ?? const FilterUpdateState.idle(),
          hasItems: state?.paged.items.isNotEmpty ?? false,
        );
      }),
    );
    ref.listen<DownloadTaskFilterState>(
      downloadTaskCenterProvider.select(
        (value) => value.value?.filter ?? DownloadTaskFilterState.initial,
      ),
      (previous, next) {
        if (previous != null && previous != next) {
          _scrollToTop();
        }
      },
    );
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final layout = AppFixedHeaderLayout(
      header: buildDownloadTaskHeader(
        context: context,
        ref: ref,
        onManualAdd: _openManualAdd,
        selection: _selection,
      ),
      child: AppFilterResultLoadingOverlay(
        isLoading: view.filterUpdate.isLoading,
        hasPreviousItems: view.hasItems,
        child: AppPagedLoadMoreScope(
          canLoadMore: () {
            final state = ref.read(downloadTaskCenterProvider).value;
            return state?.paged.canAutoLoadMore ?? false;
          },
          onLoadMore: _controller.loadMore,
          child: isMobile
              ? AppAdaptiveRefreshScrollView(
                  controller: _scrollController,
                  onRefresh: _refresh,
                  // AppAdaptiveRefreshScrollView 自带底部安全区。
                  slivers: buildDownloadTaskSlivers(
                    onManualAdd: _openManualAdd,
                    selection: _selection,
                  ),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    ...buildDownloadTaskSlivers(
                      onManualAdd: _openManualAdd,
                      selection: _selection,
                    ),
                    ...bottomSafeAreaSliver(context),
                  ],
                ),
        ),
      ),
    );
    return AppPageRefreshScope(
      onRefresh: _refresh,
      // 移动端多选态需要贴底批量操作条；桌面动作在顶栏里。
      child: wrapDownloadTaskSelectionBar(
        context: context,
        ref: ref,
        selection: _selection,
        child: KeyedSubtree(
          key: const Key('download-tasks-page'),
          child: layout,
        ),
      ),
    );
  }
}
