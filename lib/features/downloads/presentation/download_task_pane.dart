import 'package:sakuramedia/core/network/api_error_message.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_placeholders.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 构建「下载任务」Tab 的 sliver 列表。
///
/// 调用方负责把返回的 slivers 放进外层 `CustomScrollView`。
Widget buildDownloadTaskHeader({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final state = ref.watch(downloadTaskCenterProvider).value;
  if (state == null) return const SizedBox.shrink();
  final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state.selectionMode)
        isMobile
            ? _MobileSelectionHeader(state: state)
            : _DesktopSelectionHeader(state: state)
      else if (isMobile)
        _DownloadFilterBar(state: state)
      else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DownloadFilterBar(state: state)),
            SizedBox(width: context.appSpacing.md),
            AppSelectionEntryButton(
              key: const Key('download-tasks-selection-entry'),
              onPressed: state.paged.items.isEmpty
                  ? null
                  : () => ref
                        .read(downloadTaskCenterProvider.notifier)
                        .enterSelectionMode(),
            ),
          ],
        ),
      AppFilterUpdateBar(
        key: const Key('download-tasks-reloading-indicator'),
        state: state.paged.filterUpdate,
        hasPreviousItems: state.paged.items.isNotEmpty,
        onRetry: () => unawaited(
          ref.read(downloadTaskCenterProvider.notifier).retryFilter(),
        ),
      ),
      SizedBox(height: context.appSpacing.lg),
    ],
  );
}

/// 移动端多选态把页面内容包成「列表 + 贴底批量操作条」；桌面或非多选态原样返回。
///
/// 下载 tab 的多选动作在桌面顶栏、移动贴底条，两处不共存。只在调用方确认当前是
/// 下载 tab 时调用，避免提前初始化下载任务 Provider。
Widget wrapDownloadTaskSelectionBar({
  required BuildContext context,
  required WidgetRef ref,
  required Widget child,
}) {
  if (AppPlatformScope.maybeOf(context) != AppPlatform.mobile) return child;
  final selectionMode = ref.watch(
    downloadTaskCenterProvider.select(
      (asyncState) => asyncState.value?.selectionMode ?? false,
    ),
  );
  if (!selectionMode) return child;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: child),
      const _MobileSelectionBar(),
    ],
  );
}

/// 桌面多选态顶栏：原地改写筛选行，批量动作与移动贴底条共用。
class _DesktopSelectionHeader extends ConsumerWidget {
  const _DesktopSelectionHeader({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadTaskCenterProvider.notifier);
    final loadedCount = state.paged.items.length;
    final allSelected = loadedCount > 0 && state.selectionCount >= loadedCount;
    return AppSelectionHeaderToolbar(
      key: const Key('download-tasks-selection-header'),
      countLabel: '已选 ${state.selectionCount} 个',
      countKey: const Key('download-tasks-selection-count'),
      selectAllLabel: allSelected ? '取消全选' : '全选（$loadedCount）',
      selectAllKey: const Key('download-tasks-select-all-button'),
      onToggleAll: loadedCount == 0 ? null : notifier.toggleSelectAllLoaded,
      exitKey: const Key('download-tasks-selection-exit'),
      onExit: notifier.exitSelectionMode,
      actions: <Widget>[
        _buildBatchDeleteButton(
          context,
          ref,
          state,
          size: AppButtonSize.small,
        ),
      ],
    );
  }
}

/// 移动端多选态顶栏：与订阅管理 / PornBox 的 `AppListHeader.selection` 同一套，
/// 危险动作下沉到贴底条 [_MobileSelectionBar]。
class _MobileSelectionHeader extends ConsumerWidget {
  const _MobileSelectionHeader({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadTaskCenterProvider.notifier);
    final loadedCount = state.paged.items.length;
    final allSelected = loadedCount > 0 && state.selectionCount >= loadedCount;
    return AppListHeader.selection(
      key: const Key('download-tasks-selection-header'),
      selectionLabel: '已选 ${state.selectionCount} 个',
      selectionExitButtonKey: const Key('download-tasks-selection-exit'),
      onExitSelection: notifier.exitSelectionMode,
      actionSlots: <Widget>[
        AppTextButton(
          key: const Key('download-tasks-select-all-button'),
          label: allSelected ? '取消全选' : '全选（$loadedCount）',
          size: AppTextButtonSize.small,
          onPressed: loadedCount == 0 ? null : notifier.toggleSelectAllLoaded,
        ),
      ],
    );
  }
}

/// 移动端贴底批量操作条：危险动作放在拇指够得到的地方。
class _MobileSelectionBar extends ConsumerWidget {
  const _MobileSelectionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadTaskCenterProvider).value;
    if (state == null) return const SizedBox.shrink();
    return AppSelectionBottomBar(
      actions: <Widget>[_buildBatchDeleteButton(context, ref, state)],
    );
  }
}

Widget _buildBatchDeleteButton(
  BuildContext context,
  WidgetRef ref,
  DownloadTaskCenterState state, {
  AppButtonSize size = AppButtonSize.medium,
}) {
  return AppButton(
    key: const Key('download-tasks-batch-delete-button'),
    label: '删除所选（${state.selectionCount}）',
    size: size,
    variant: AppButtonVariant.danger,
    icon: const Icon(Icons.delete_outline_rounded),
    onPressed: state.hasSelection
        ? () => unawaited(_deleteSelectedTasks(context, ref))
        : null,
  );
}

/// 批量删除所选下载任务：复用下载任务删除弹窗（确认 +「同时删除下载器文件」），
/// `showProgress` 下逐条 `DELETE /download-tasks/{id}` 并展示进度条；成功项随删
/// 随从列表移除，失败项保留在列表里等用户处理。
Future<void> _deleteSelectedTasks(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(downloadTaskCenterProvider.notifier);
  final tasks = notifier.selectedLoadedTasks();
  if (tasks.isEmpty) return;
  final confirmed = await showDownloadTaskDeleteDialog(
    context,
    tasks: tasks,
    showProgress: true,
    onDelete: (id, deleteFiles) =>
        notifier.deleteTask(id, deleteFiles: deleteFiles),
  );
  if (!context.mounted || !confirmed) return;
  final removed = tasks.length - notifier.selectedLoadedTasks().length;
  notifier.exitSelectionMode();
  if (removed > 0) showToast('已删除 $removed 个下载任务');
}

List<Widget> buildDownloadTaskSlivers({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final asyncState = ref.watch(downloadTaskCenterProvider);

  if (asyncState.isLoading && !asyncState.hasValue) {
    // loading 用占位任务渲染真实任务卡，由 [AppSkeletonizer] 灰化。
    final placeholders = downloadTaskPlaceholders();
    return <Widget>[
      AppSkeletonizer.sliver(
        enabled: true,
        child: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final isLast = index == placeholders.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : context.appSpacing.md,
              ),
              child: RepaintBoundary(
                child: _DownloadTaskCard(row: placeholders[index]),
              ),
            );
          }, childCount: placeholders.length),
        ),
      ),
    ];
  }
  if (asyncState.hasError && !asyncState.hasValue) {
    return <Widget>[
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: apiErrorMessage(
            asyncState.error!,
            fallback: '下载任务加载失败，请稍后重试',
          ),
          onRetry: () => ref.invalidate(downloadTaskCenterProvider),
        ),
      ),
    ];
  }

  final state = asyncState.requireValue;
  final slivers = <Widget>[];

  final items = state.paged.items;
  if (items.isEmpty) {
    if (state.paged.filterUpdate.hasFailed) return slivers;
    // 有筛选时给一个可以「清除筛选」的重试入口，避免用户困惑「明明有任务却看不到」。
    final hasFilter = !state.filter.isDefault;
    slivers.add(
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: hasFilter ? '没有符合筛选条件的下载任务' : '暂无下载任务',
          icon: hasFilter ? Icons.search_off_rounded : Icons.download_outlined,
          onRetry: hasFilter
              ? () => unawaited(
                  ref
                      .read(downloadTaskCenterProvider.notifier)
                      .applyFilter(DownloadTaskFilterState.initial),
                )
              : null,
          retryLabel: '清除筛选',
          retryKey: const Key('download-empty-clear-filter'),
        ),
      ),
    );
    return slivers;
  }

  slivers.add(
    SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final row = items[index];
        final isLast = index == items.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.md),
          child: RepaintBoundary(child: _DownloadTaskCard(row: row)),
        );
      }, childCount: items.length),
    ),
  );

  if (state.paged.hasMore || state.paged.loadMoreErrorMessage != null) {
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: state.paged.isLoadingMore,
              errorMessage: state.paged.loadMoreErrorMessage,
              onRetry: () => unawaited(
                ref.read(downloadTaskCenterProvider.notifier).loadMore(),
              ),
            ),
            SizedBox(height: context.appSpacing.xl),
          ],
        ),
      ),
    );
  }
  return slivers;
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.row});

  final DownloadTaskRowState row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 首屏骨架渲染占位行时 provider 还没有 value，退回初始状态取空选择 / 空客户端名。
    final state =
        ref.watch(downloadTaskCenterProvider).value ??
        DownloadTaskCenterState.initial;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final task = row.task;
    final progress = row.progress.clamp(0.0, 1.0);
    final taskState = row.state;
    final isPending = state.isTaskPending(task.id);
    final isImportRunning = task.importStatus == 'running';
    final movieNumber = task.movieNumber;
    final hasMovieNumber = (movieNumber ?? '').isNotEmpty;
    final displayTitle = _resolveDisplayTitle(task);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final selectionMode = state.selectionMode;
    final isSelected = state.isSelected(task.id);
    final thinCoverUrl = task.movieThinCover?.bestAvailableUrl.trim() ?? '';
    final wideCoverUrl = task.movieCover?.bestAvailableUrl.trim() ?? '';
    final coverUrl = isMobile && thinCoverUrl.isNotEmpty
        ? thinCoverUrl
        : wideCoverUrl;

    // 骨架态整卡收敛成一块 shimmer 圆角块：进度条 / 状态角标不再透出自有颜色。
    return Skeleton.unite(
      borderRadius: context.appRadius.mdBorder,
      child: AppLeftCoverCard(
        key: Key('download-task-${task.id}'),
        coverWidth: componentTokens.downloadTaskCoverWidth,
        bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
        selected: selectionMode && isSelected,
        onTap: selectionMode
            ? () => ref
                  .read(downloadTaskCenterProvider.notifier)
                  .toggleSelection(task.id)
            : null,
        cover: _DownloadTaskCover(
          coverUrl: coverUrl,
          movieNumber: hasMovieNumber ? movieNumber : null,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: selectionMode || !hasMovieNumber
              ? null
              : () {
                  if (isMobile) {
                    context.pushMobileMovieDetail(movieNumber: movieNumber!);
                    return;
                  }
                  context.pushDesktopMovieDetail(
                    movieNumber: movieNumber!,
                    fallbackPath: desktopActivityPath,
                  );
                },
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 番号：把用户"扫一眼找番号"的心智放最顶。空番号（predownload）不渲染。
            if (hasMovieNumber)
              AppBadge(
                key: Key('download-task-movie-number-${movieNumber!}'),
                label: movieNumber,
                tone: AppBadgeTone.neutral,
                size: AppBadgeSize.compact,
              ),
            if (hasMovieNumber) SizedBox(height: context.appSpacing.xs),
            // ② 标题：中文标题优先，1 行 ellipsis。
            Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
            // ③ 进度条：已完成态用中性灰，避免深色进度条抢眼。
            ClipRRect(
              borderRadius: context.appRadius.pillBorder,
              child: LinearProgressIndicator(
                minHeight: componentTokens.downloadTaskProgressHeight,
                value: progress,
                backgroundColor: colors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progressBarColor(context, taskState),
                ),
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
            // ④ 下载状态一行：状态 badge + 百分比 + 导入短标签
            Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppBadge(
                  label: _labelForDownloadState(taskState),
                  tone: _toneForDownloadState(taskState),
                  size: AppBadgeSize.compact,
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: _statTextStyle(context),
                ),
                // 导入 badge 用短标签，完整文案挂 Tooltip 里
                if (task.importStatusLabel.isNotEmpty)
                  Tooltip(
                    message: task.importStatusLabel,
                    child: AppBadge(
                      label: _shortImportLabel(
                        task.importStatus,
                        fallback: task.importStatusLabel,
                      ),
                      tone: _toneForImportStatus(task.importStatus),
                      size: AppBadgeSize.compact,
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.appSpacing.sm),
            // ⑤ 客户端 + 创建时间（靠左）+ 操作按钮（靠右）
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: context.appSpacing.sm,
                    runSpacing: context.appSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        state.clientNameOf(task.clientId),
                        style: _footnoteTextStyle(context),
                      ),
                      if (formatUpdatedAtLabel(task.createdAt) != null)
                        Text(
                          '创建 ${formatUpdatedAtLabel(task.createdAt)}',
                          style: _footnoteTextStyle(context),
                        ),
                    ],
                  ),
                ),
                if (!selectionMode && _canRetriggerImport(task)) ...[
                  AppIconButton(
                    key: Key('download-task-retrigger-import-${task.id}'),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: '重新导入',
                    onPressed: isPending
                        ? null
                        : () => unawaited(_triggerImport(context, ref, task.id)),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                ],
                if (!selectionMode)
                  AppIconButton(
                    key: Key('download-task-delete-${task.id}'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: isImportRunning ? '任务正在导入，无法删除' : '删除',
                    onPressed: (isPending || isImportRunning)
                        ? null
                        : () => showDownloadTaskDeleteDialog(
                            context,
                            tasks: [task],
                            onDelete: (id, deleteFiles) => ref
                                .read(downloadTaskCenterProvider.notifier)
                                .deleteTask(id, deleteFiles: deleteFiles),
                          ),
                  ),
              ],
            ),
          ],
          ),
        ),
    );
  }

  static String _resolveDisplayTitle(DownloadTaskDto task) {
    final movieTitle = (task.movieTitle ?? '').trim();
    if (movieTitle.isNotEmpty) {
      return movieTitle;
    }
    return task.name.isEmpty ? task.remoteId : task.name;
  }
}

TextStyle _statTextStyle(BuildContext context) => resolveAppTextStyle(
  context,
  size: AppTextSize.s12,
  weight: AppTextWeight.regular,
  tone: AppTextTone.muted,
);

TextStyle _footnoteTextStyle(BuildContext context) => resolveAppTextStyle(
  context,
  size: AppTextSize.s10,
  weight: AppTextWeight.regular,
  tone: AppTextTone.tertiary,
);

Color _progressBarColor(BuildContext context, String state) {
  final palette = context.appTextPalette;
  final colors = context.appColors;
  return switch (state) {
    'downloading' => palette.accent,
    'failed' => palette.error,
    _ => colors.borderStrong,
  };
}

/// 导入状态短标签映射。后端 `describe_import_status` 里的完整中文（如
/// "已导入：媒体文件全部成功入库"）在 badge 上过长；这里给出 4 字内的短版，
/// 完整文案通过 Tooltip 保留在 hover 里。
String _shortImportLabel(String status, {required String fallback}) {
  return switch (status) {
    'pending' => '待导入',
    'running' => '导入中',
    'completed' => '已导入',
    'failed' => '导入失败',
    'skipped' => '已跳过',
    _ => fallback,
  };
}

/// 只有导入已跑完且没成功的任务才给「重新导入」；pending/running 在途、
/// completed 已入库，都不需要。
bool _canRetriggerImport(DownloadTaskDto task) =>
    task.importStatus == 'failed' || task.importStatus == 'skipped';

Future<void> _triggerImport(
  BuildContext context,
  WidgetRef ref,
  int taskId,
) async {
  try {
    await ref.read(downloadTaskCenterProvider.notifier).triggerImport(taskId);
    if (context.mounted) showToast('已提交导入任务');
  } catch (error) {
    if (context.mounted) {
      showToast(apiErrorMessage(error, fallback: '提交导入失败，请稍后重试'));
    }
  }
}

/// 卡片左侧封面由外层 Positioned 提供固定宽度和全高约束，贴合卡片上下缘。
/// 圆角由最外层卡片 `clipBehavior` 统一裁剪；仅封面本身接收详情跳转，避免误吞右侧操作。
///
/// 多选态封面只作展示 + 左上角勾选标记，点击交给整卡统一处理。
class _DownloadTaskCover extends StatelessWidget {
  const _DownloadTaskCover({
    required this.coverUrl,
    required this.movieNumber,
    required this.onTap,
    required this.selectionMode,
    required this.isSelected,
  });

  final String coverUrl;
  final String? movieNumber;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // 横向封面居中裁切，圆角由外层下载任务卡统一处理。
    final image = MaskedImage(
      url: coverUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );

    final Widget content;
    if (onTap == null) {
      content = image;
    } else {
      content = Semantics(
        button: true,
        label: '查看影片详情：${movieNumber ?? ''}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            key: Key('download-task-cover-tap-${movieNumber ?? ''}'),
            onTap: onTap,
            child: image,
          ),
        ),
      );
    }

    if (!selectionMode) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        PositionedDirectional(
          top: context.appSpacing.sm,
          start: context.appSpacing.sm,
          child: SelectionCheckBadge(isSelected: isSelected),
        ),
      ],
    );
  }
}

String _labelForDownloadState(String state) {
  return switch (state) {
    'downloading' => '下载中',
    'queued' => '排队中',
    'completed' => '已完成',
    'failed' => '失败',
    _ => state.isEmpty ? '未知' : state,
  };
}

AppBadgeTone _toneForDownloadState(String state) {
  return switch (state) {
    'downloading' => AppBadgeTone.primary,
    'queued' => AppBadgeTone.neutral,
    'completed' => AppBadgeTone.success,
    'failed' => AppBadgeTone.error,
    _ => AppBadgeTone.neutral,
  };
}

AppBadgeTone _toneForImportStatus(String state) {
  return switch (state) {
    'running' => AppBadgeTone.primary,
    'completed' => AppBadgeTone.success,
    'failed' => AppBadgeTone.error,
    'pending' || 'skipped' => AppBadgeTone.neutral,
    _ => AppBadgeTone.neutral,
  };
}

/// 下载任务筛选栏：番号搜索（回车提交）+ 状态下拉 + 客户端下拉（仅在客户端 ≥2 时显示）。
///
/// 遵循「筛选状态驱动」范式：所有变更走 `notifier.applyFilter(...)`。
/// 搜索输入沿用项目其它筛选栏习惯——**不做打字 debounce**，仅回车/失焦提交。
class _DownloadFilterBar extends StatelessWidget {
  const _DownloadFilterBar({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context) {
    if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
      return _MobileDownloadFilterEntry(state: state);
    }
    return _DesktopDownloadFilterBar(state: state);
  }
}

class _DesktopDownloadFilterBar extends HookConsumerWidget {
  const _DesktopDownloadFilterBar({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController(
      text: state.filter.search,
    );
    // 若外部通过其它入口（如「清除筛选」）改了 filter.search，同步进输入框；
    // 用户正在输入时（controller.text 与最近同步值不一致）避免打断。
    final attachedSearch = useRef<String>(state.filter.search);
    useEffect(() {
      final external = state.filter.search;
      if (external != attachedSearch.value &&
          external != searchController.text) {
        searchController.text = external;
      }
      attachedSearch.value = external;
      return null;
    }, [state.filter.search]);

    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    final clientOptions = state.clientOptions;

    Future<void> submitSearch(String value) async {
      final next = state.filter.copyWith(search: value.trim());
      attachedSearch.value = next.search;
      await ref.read(downloadTaskCenterProvider.notifier).applyFilter(next);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthLg,
          child: AppTextField(
            fieldKey: const Key('download-filter-search'),
            controller: searchController,
            hintText: '按番号搜索',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: submitSearch,
            enabled: true,
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<DownloadTaskStateFilter>(
            key: const Key('download-filter-state'),
            value: state.filter.stateFilter,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: DownloadTaskStateFilter.values
                .map(
                  (value) => DropdownMenuItem<DownloadTaskStateFilter>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => ref
                .read(downloadTaskCenterProvider.notifier)
                .applyFilter(
                  state.filter.copyWith(
                    stateFilter: value ?? DownloadTaskStateFilter.downloading,
                  ),
                ),
          ),
        ),
        if (clientOptions.length >= 2)
          SizedBox(
            width: layoutTokens.filterFieldWidthMd,
            child: AppSelectField<int?>(
              key: const Key('download-filter-client'),
              value: state.filter.clientId,
              size: AppSelectFieldSize.compact,
              textStyle: filterTextStyle,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(value: null, child: Text('全部客户端')),
                for (final option in clientOptions)
                  DropdownMenuItem<int?>(
                    value: option.id,
                    child: Text(option.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => ref
                  .read(downloadTaskCenterProvider.notifier)
                  .applyFilter(state.filter.copyWith(clientId: value)),
            ),
          ),
      ],
    );
  }
}

class _MobileDownloadFilterEntry extends ConsumerWidget {
  const _MobileDownloadFilterEntry({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = state.filter;
    final isSelected = !filter.isDefault;
    return Row(
      children: [
        Expanded(
          child: Text(
            _downloadFilterSummary(filter, state.clientOptions),
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
        AppSelectionEntryButton(
          key: const Key('download-tasks-selection-entry'),
          onPressed: state.paged.items.isEmpty
              ? null
              : () => ref
                    .read(downloadTaskCenterProvider.notifier)
                    .enterSelectionMode(),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppButton(
          key: const Key('mobile-download-filter-button'),
          label: isSelected ? '已筛选' : '筛选',
          icon: const Icon(Icons.tune_rounded),
          size: AppButtonSize.small,
          isSelected: isSelected,
          onPressed: () => _showMobileDownloadFilterDrawer(
            context,
            current: filter,
            clientOptions: state.clientOptions,
            onChanged: (next) => unawaited(
              ref.read(downloadTaskCenterProvider.notifier).applyFilter(next),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showMobileDownloadFilterDrawer(
  BuildContext context, {
  required DownloadTaskFilterState current,
  required List<DownloadClientOption> clientOptions,
  required ValueChanged<DownloadTaskFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-download-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (_) => _MobileDownloadFilterDrawerContent(
      current: current,
      clientOptions: clientOptions,
      onChanged: onChanged,
    ),
  );
}

class _MobileDownloadFilterDrawerContent extends StatefulWidget {
  const _MobileDownloadFilterDrawerContent({
    required this.current,
    required this.clientOptions,
    required this.onChanged,
  });

  final DownloadTaskFilterState current;
  final List<DownloadClientOption> clientOptions;
  final ValueChanged<DownloadTaskFilterState> onChanged;

  @override
  State<_MobileDownloadFilterDrawerContent> createState() =>
      _MobileDownloadFilterDrawerContentState();
}

class _MobileDownloadFilterDrawerContentState
    extends State<_MobileDownloadFilterDrawerContent> {
  late DownloadTaskFilterState _local;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
    _searchController = TextEditingController(text: _local.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply(DownloadTaskFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-download-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () {
          _searchController.clear();
          _apply(DownloadTaskFilterState.initial);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '筛选下载任务',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.lg),
          AppTextField(
            fieldKey: const Key('mobile-download-filter-search'),
            controller: _searchController,
            label: '番号',
            hintText: '按番号搜索',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (value) =>
                _apply(_local.copyWith(search: value.trim())),
          ),
          SizedBox(height: context.appSpacing.md),
          AppSelectField<DownloadTaskStateFilter>(
            key: const Key('mobile-download-filter-state'),
            label: '下载状态',
            value: _local.stateFilter,
            items: DownloadTaskStateFilter.values
                .map(
                  (value) => DropdownMenuItem<DownloadTaskStateFilter>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => _apply(
              _local.copyWith(
                stateFilter: value ?? DownloadTaskStateFilter.downloading,
              ),
            ),
          ),
          if (widget.clientOptions.length >= 2) ...[
            SizedBox(height: context.appSpacing.md),
            AppSelectField<int?>(
              key: const Key('mobile-download-filter-client'),
              label: '下载客户端',
              value: _local.clientId,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(value: null, child: Text('全部客户端')),
                for (final option in widget.clientOptions)
                  DropdownMenuItem<int?>(
                    value: option.id,
                    child: Text(option.name),
                  ),
              ],
              onChanged: (value) => _apply(_local.copyWith(clientId: value)),
            ),
          ],
        ],
      ),
    );
  }
}

String _downloadFilterSummary(
  DownloadTaskFilterState filter,
  List<DownloadClientOption> clientOptions,
) {
  final values = <String>[filter.stateFilter.label];
  if (filter.normalizedSearch.isNotEmpty) {
    values.add(filter.normalizedSearch);
  }
  final clientId = filter.clientId;
  if (clientId != null) {
    final client = clientOptions.where((item) => item.id == clientId);
    values.add(client.isEmpty ? '指定客户端' : client.first.name);
  }
  return values.join(' · ');
}
