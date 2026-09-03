import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 构建「下载任务」Tab 的 sliver 列表。
///
/// 调用方负责把返回的 slivers 放进外层 `CustomScrollView`。
List<Widget> buildDownloadTaskSlivers({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final asyncState = ref.watch(downloadTaskCenterProvider);

  if (asyncState.isLoading && !asyncState.hasValue) {
    return const <Widget>[SliverToBoxAdapter(child: _DownloadInitialLoading())];
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
  final slivers = <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.lg),
        child: _DownloadFilterBar(state: state),
      ),
    ),
    if (state.paged.filterUpdate.hasFailed)
      SliverToBoxAdapter(
        key: const Key('download-tasks-reloading-indicator'),
        child: Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: AppFilterUpdateBar(
            state: state.paged.filterUpdate,
            hasPreviousItems: state.paged.items.isNotEmpty,
            onRetry: () => unawaited(
              ref.read(downloadTaskCenterProvider.notifier).retryFilter(),
            ),
          ),
        ),
      ),
  ];

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

class _DownloadInitialLoading extends StatelessWidget {
  const _DownloadInitialLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxl),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.row});

  final DownloadTaskRowState row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadTaskCenterProvider).requireValue;
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
    final coverUrl = task.movieCover?.bestAvailableUrl ?? '';
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;

    return AppLeftCoverCard(
      key: Key('download-task-${task.id}'),
      coverWidth: componentTokens.downloadTaskCoverWidth,
      bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
      cover: _DownloadTaskCover(
        coverUrl: coverUrl,
        movieNumber: hasMovieNumber ? movieNumber : null,
        onTap: hasMovieNumber
            ? () {
                if (isMobile) {
                  context.pushMobileMovieDetail(movieNumber: movieNumber!);
                  return;
                }
                context.pushDesktopMovieDetail(
                  movieNumber: movieNumber!,
                  fallbackPath: desktopActivityPath,
                );
              }
            : null,
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
              AppIconButton(
                key: Key('download-task-delete-${task.id}'),
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: isImportRunning ? '任务正在导入，无法删除' : '删除',
                onPressed: (isPending || isImportRunning)
                    ? null
                    : () => _confirmDelete(context, ref, task),
              ),
            ],
          ),
        ],
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

/// 卡片左侧封面由外层 Positioned 提供固定宽度和全高约束，贴合卡片上下缘。
/// 圆角由最外层卡片 `clipBehavior` 统一裁剪；仅封面本身接收详情跳转，避免误吞右侧操作。
class _DownloadTaskCover extends StatelessWidget {
  const _DownloadTaskCover({
    required this.coverUrl,
    required this.movieNumber,
    required this.onTap,
  });

  final String coverUrl;
  final String? movieNumber;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 横向封面居中裁切，圆角由外层下载任务卡统一处理。
    final image = MaskedImage(
      url: coverUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );

    if (onTap == null) {
      return image;
    }
    return Semantics(
      button: true,
      label: '查看影片详情：${movieNumber ?? ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('download-task-cover-tap-${movieNumber ?? ''}'),
          onTap: onTap,
          child: image,
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  DownloadTaskDto task,
) async {
  var deleteFiles = false;
  await showAppConfirmDialog(
    context,
    dialogKey: const Key('download-task-delete-dialog'),
    title: '删除下载任务',
    message: '确认删除任务「${task.name.isEmpty ? task.remoteId : task.name}」？',
    danger: true,
    confirmLabel: '删除',
    failureFallback: '删除失败',
    extraContent: _DeleteFilesCheckbox(
      onChanged: (value) => deleteFiles = value,
    ),
    onConfirm: () async {
      try {
        await ref
            .read(downloadTaskCenterProvider.notifier)
            .deleteTask(task.id, deleteFiles: deleteFiles);
      } catch (error) {
        // 抛一个只带 message 的 ApiException，让 confirm dialog 的
        // apiErrorMessage 直接吐出我们映射的中文（error.error 留空 →
        // 走 message 分支）。
        throw ApiException(
          message: _downloadErrorMessage(error, fallback: '删除失败'),
        );
      }
    },
  );
}

String _downloadErrorMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    final code = error.error?.code;
    switch (code) {
      case 'download_task_import_running':
        return '任务正在导入，无法删除';
    }
  }
  return apiErrorMessage(error, fallback: fallback);
}

class _DeleteFilesCheckbox extends HookWidget {
  const _DeleteFilesCheckbox({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final deleteFiles = useState(false);

    void toggle(bool value) {
      deleteFiles.value = value;
      onChanged(value);
    }

    return InkWell(
      onTap: () => toggle(!deleteFiles.value),
      borderRadius: context.appRadius.smBorder,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              key: const Key('download-task-delete-files-checkbox'),
              value: deleteFiles.value,
              onChanged: (value) => toggle(value ?? false),
            ),
            SizedBox(width: context.appSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同时删除下载器中的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs / 2),
                  Text(
                    '不影响已导入媒体库的文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
