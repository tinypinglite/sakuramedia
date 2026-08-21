import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/format/transfer_speed.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_file_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

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
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: _DownloadClientSpeedBar(state: state),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.lg),
        child: _DownloadFilterBar(state: state),
      ),
    ),
    if (!state.paged.filterUpdate.isIdle)
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

class _DownloadClientSpeedBar extends StatelessWidget {
  const _DownloadClientSpeedBar({required this.state});

  final DownloadTaskCenterState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasAnyLiveData = state.paged.items.any(
      (row) =>
          row.task.downloadSpeedBytes > 0 || row.task.uploadedSpeedBytes > 0,
    );
    final totalDown = state.totalDownloadSpeedBytes;
    final totalUp = state.totalUploadSpeedBytes;

    return Container(
      key: const Key('download-client-speed-bar'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.lg,
        vertical: context.appSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SpeedSummaryLabel(
            icon: Icons.arrow_downward_rounded,
            value: hasAnyLiveData ? formatTransferSpeed(totalDown) : '—',
          ),
          SizedBox(width: context.appSpacing.md),
          _SpeedSummaryLabel(
            icon: Icons.arrow_upward_rounded,
            value: hasAnyLiveData ? formatTransferSpeed(totalUp) : '—',
          ),
          SizedBox(width: context.appSpacing.lg),
          Expanded(
            child: Wrap(
              spacing: context.appSpacing.sm,
              runSpacing: context.appSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const AppBadge(
                  key: Key('download-client-snapshot-status'),
                  label: '列表快照',
                  tone: AppBadgeTone.neutral,
                  size: AppBadgeSize.compact,
                ),
              ],
            ),
          ),
          if (state.pollingState != DownloadTaskPollingState.idle) ...[
            SizedBox(width: context.appSpacing.sm),
            _DownloadPollingBadge(state: state.pollingState),
          ],
        ],
      ),
    );
  }
}

class _SpeedSummaryLabel extends StatelessWidget {
  const _SpeedSummaryLabel({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: context.appComponentTokens.iconSizeSm,
          color: context.appTextPalette.secondary,
        ),
        SizedBox(width: context.appSpacing.xs),
        Text(
          value,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
      ],
    );
  }
}

class _DownloadPollingBadge extends StatelessWidget {
  const _DownloadPollingBadge({required this.state});

  final DownloadTaskPollingState state;

  @override
  Widget build(BuildContext context) {
    return const AppBadge(
      key: Key('download-task-polling-badge'),
      label: '轮询中',
      tone: AppBadgeTone.info,
      size: AppBadgeSize.compact,
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
    final downloadState = row.downloadState;
    final isPending = state.isTaskPending(task.id);
    final isImportRunning = task.importStatus == 'running';
    final clientKind = state.clientKindOf(task.clientId);
    final isCloud115 = clientKind == DownloadClientKind.cloud115;
    final movieNumber = task.movieNumber;
    final hasMovieNumber = (movieNumber ?? '').isNotEmpty;
    final displayTitle = _resolveDisplayTitle(task);
    final coverUrl = task.movieCover?.bestAvailableUrl ?? '';

    return AppLeftCoverCard(
      key: Key('download-task-${task.id}'),
      coverWidth: componentTokens.downloadTaskCoverWidth,
      bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
      cover: _DownloadTaskCover(
        coverUrl: coverUrl,
        movieNumber: hasMovieNumber ? movieNumber : null,
        onTap: hasMovieNumber
            ? () => context.pushDesktopMovieDetail(
                movieNumber: movieNumber!,
                fallbackPath: desktopActivityPath,
              )
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
          // ③ 进度条：做种/已完成态用中性灰，避免深红"血条"抢眼。
          ClipRRect(
            borderRadius: context.appRadius.pillBorder,
            child: LinearProgressIndicator(
              minHeight: componentTokens.downloadTaskProgressHeight,
              value: progress,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progressBarColor(context, downloadState),
              ),
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          // ④ 下载状态一行：状态 badge + 百分比 + 大小 + 速度 + eta + 导入短标签
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: _labelForDownloadState(downloadState),
                tone: _toneForDownloadState(downloadState),
                size: AppBadgeSize.compact,
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: _statTextStyle(context),
              ),
              if (task.totalSizeBytes > 0)
                Text(
                  '${formatFileSize(task.downloadedBytes)} / ${formatFileSize(task.totalSizeBytes)}',
                  style: _statTextStyle(context),
                ),
              if (downloadState == 'downloading' && task.downloadSpeedBytes > 0) ...[
                Text(
                  '↓${formatTransferSpeed(task.downloadSpeedBytes)}',
                  style: _statTextStyle(context),
                ),
                Text(
                  '↑${formatTransferSpeed(task.uploadedSpeedBytes)}',
                  style: _statTextStyle(context),
                ),
              ],
              // 做种态：下载已完成，只展示上传速度（"贡献速率"）
              if (downloadState == 'seeding' && task.uploadedSpeedBytes > 0)
                Text(
                  '↑${formatTransferSpeed(task.uploadedSpeedBytes)}',
                  style: _statTextStyle(context),
                ),
              if ((task.etaSeconds ?? 0) > 0)
                Text(
                  '剩余 ${formatMediaDurationLabel(task.etaSeconds!)}',
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
              // 文件列表：按需拉取（qB / 115 通用），不进 SSE 快照保持列表轻量。
              SizedBox(width: context.appSpacing.sm),
              AppIconButton(
                key: Key('download-task-files-${task.id}'),
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: '文件列表',
                semanticLabel: '文件列表',
                onPressed: () => showAppAdaptiveModal(
                  context: context,
                  modalKey: Key('download-task-files-dialog-${task.id}'),
                  desktopWidth: 560,
                  desktopHeight: 480,
                  builder: (_) => _DownloadTaskFilesDialog(
                    taskId: task.id,
                    taskName: displayTitle,
                  ),
                ),
              ),
              // 已完成不显示暂停/恢复；做种态可以暂停（停止上传）。
              if (!isCloud115 && downloadState == 'paused')
                AppIconButton(
                  key: Key('download-task-resume-${task.id}'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: '恢复',
                  onPressed: isPending
                      ? null
                      : () => _resume(context, ref, task.id),
                )
              else if (!isCloud115 && downloadState != 'completed')
                AppIconButton(
                  key: Key('download-task-pause-${task.id}'),
                  icon: const Icon(Icons.pause_rounded),
                  tooltip: '暂停',
                  onPressed: isPending
                      ? null
                      : () => _pause(context, ref, task.id),
                ),
              if (!isCloud115 && downloadState != 'completed')
                SizedBox(width: context.appSpacing.xs),
              AppIconButton(
                key: Key('download-task-delete-${task.id}'),
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: isImportRunning ? '任务正在导入，无法删除' : '删除',
                onPressed: (isPending || isImportRunning)
                    ? null
                    : () => _confirmDelete(
                        context,
                        ref,
                        task,
                        isCloud115: isCloud115,
                      ),
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
    return task.name.isEmpty ? task.infoHash : task.name;
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

/// 进度条颜色：下载中用品牌强调色（用户主动关注）；做种/已完成/暂停用中性灰
/// 避免"血条"式视觉抢眼；失败态用主题 error；其余中性。
Color _progressBarColor(BuildContext context, String downloadState) {
  final palette = context.appTextPalette;
  final colors = context.appColors;
  return switch (downloadState) {
    'downloading' => palette.accent,
    'checking' => palette.info,
    'failed' => palette.error,
    // 做种 / 已完成 / 已暂停 / 排队 / 停滞 都用中性灰，不再抢焦点
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

Future<void> _pause(BuildContext context, WidgetRef ref, int taskId) async {
  try {
    await ref.read(downloadTaskCenterProvider.notifier).pauseTask(taskId);
  } catch (error) {
    if (!context.mounted) return;
    showToast(_downloadErrorMessage(error, fallback: '暂停失败'));
  }
}

Future<void> _resume(BuildContext context, WidgetRef ref, int taskId) async {
  try {
    await ref.read(downloadTaskCenterProvider.notifier).resumeTask(taskId);
  } catch (error) {
    if (!context.mounted) return;
    showToast(_downloadErrorMessage(error, fallback: '恢复失败'));
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  DownloadTaskDto task, {
  required bool isCloud115,
}) async {
  var deleteFiles = false;
  await showAppConfirmDialog(
    context,
    dialogKey: const Key('download-task-delete-dialog'),
    title: '删除下载任务',
    message: '确认删除任务「${task.name.isEmpty ? task.infoHash : task.name}」？',
    danger: true,
    confirmLabel: '删除',
    failureFallback: '删除失败',
    extraContent: _DeleteFilesCheckbox(
      isCloud115: isCloud115,
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
      case 'download_task_remote_missing':
        return '任务在下载器中已不存在';
      case 'download_task_not_managed':
        return '该任务不受本系统管理';
      case 'download_task_import_running':
        return '任务正在导入，无法删除';
      case 'download_task_action_unsupported':
        return '115 离线任务不支持暂停或恢复';
      case 'cloud115_offline_quota_exceeded':
        return '115 本月离线下载配额已用尽';
      case 'cloud115_offline_task_exists_unmanaged':
        return '该资源已存在于 115 的非托管目录，无法接管';
    }
  }
  return apiErrorMessage(error, fallback: fallback);
}

class _DeleteFilesCheckbox extends HookWidget {
  const _DeleteFilesCheckbox({
    required this.onChanged,
    required this.isCloud115,
  });

  final ValueChanged<bool> onChanged;
  final bool isCloud115;

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
                    isCloud115 ? '同时删除 115 中已下载的文件' : '同时删除下载器里的种子文件',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: context.appSpacing.xs / 2),
                  Text(
                    isCloud115 ? '已导入媒体库的文件不受影响' : '不影响已导入媒体库的文件',
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
    'seeding' => '做种中',
    'completed' => '已完成',
    'paused' => '已暂停',
    'failed' => '失败',
    'stalled' => '等待资源',
    'stalled_dead' => '死种',
    'checking' => '校验中',
    'queued' => '排队中',
    'abandoned' => '已放弃跟踪',
    _ => state.isEmpty ? '未知' : state,
  };
}

AppBadgeTone _toneForDownloadState(String state) {
  return switch (state) {
    'downloading' => AppBadgeTone.primary,
    // seeding = 已完成 + 正在贡献，用 info 区别于纯完成态，保持视觉温度。
    'seeding' => AppBadgeTone.info,
    'completed' => AppBadgeTone.success,
    'paused' => AppBadgeTone.neutral,
    'failed' => AppBadgeTone.error,
    'stalled' => AppBadgeTone.warning,
    // 死种：qB 侧 stalledDL 躺太久被本地判死，比"等待资源"更严重，用 error 提示。
    'stalled_dead' => AppBadgeTone.error,
    'checking' => AppBadgeTone.info,
    'queued' => AppBadgeTone.neutral,
    'abandoned' => AppBadgeTone.warning,
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
class _DownloadFilterBar extends HookConsumerWidget {
  const _DownloadFilterBar({required this.state});

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
                    child: Text(
                      '${option.name} · ${option.kind.label}',
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// 下载任务文件列表弹窗。
///
/// 打开时按任务 id 实时拉取（qB / 115 各自从远端取），失败可原地重试；
/// 纯查看型展示，不参与任何导入/删除逻辑。
class _DownloadTaskFilesDialog extends ConsumerStatefulWidget {
  const _DownloadTaskFilesDialog({
    required this.taskId,
    required this.taskName,
  });

  final int taskId;
  final String taskName;

  @override
  ConsumerState<_DownloadTaskFilesDialog> createState() =>
      _DownloadTaskFilesDialogState();
}

class _DownloadTaskFilesDialogState
    extends ConsumerState<_DownloadTaskFilesDialog> {
  late Future<DownloadTaskFilesDto> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<DownloadTaskFilesDto> _fetch() =>
      ref.read(downloadsApiProvider).getTaskFiles(widget.taskId);

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  bool _isSourceUnavailable(Object error) {
    return error is ApiException &&
        error.error?.code == 'cloud115_download_task_source_unavailable';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '文件列表',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          widget.taskName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.md),
        Expanded(
          child: FutureBuilder<DownloadTaskFilesDto>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: AppInlineSpinner());
              }
              if (snapshot.hasError) {
                final sourceUnavailable = _isSourceUnavailable(snapshot.error!);
                return AppEmptyState(
                  key: const Key('download-task-files-error'),
                  icon: Icons.folder_off_outlined,
                  title: sourceUnavailable ? '源目录已不存在' : '读取文件列表失败',
                  message: apiErrorMessage(
                    snapshot.error!,
                    fallback: sourceUnavailable
                        ? '115 下载任务的源目录已被清理或删除，无法读取文件列表'
                        : '请稍后重试',
                  ),
                  onRetry: sourceUnavailable ? null : _reload,
                );
              }
              final files =
                  snapshot.data?.files ?? const <DownloadTaskFileDto>[];
              if (files.isEmpty) {
                return const AppEmptyState(
                  key: Key('download-task-files-empty'),
                  icon: Icons.folder_open_outlined,
                  message: '该任务暂无文件记录',
                );
              }
              return ListView.separated(
                key: const Key('download-task-files-list'),
                itemCount: files.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: spacing.sm),
                itemBuilder: (context, index) =>
                    _DownloadTaskFileRow(file: files[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 常见光盘镜像后缀，仅用于文件列表里视觉提示"这个格式导不进去"，
/// 不参与任何导入判定（导入判定以后端扩展名白名单为准）。
const Set<String> _kUnsupportedDiskImageExtensions = {
  'iso',
  'img',
  'mdf',
  'nrg',
  'bin',
  'cue',
};

bool _isUnsupportedDiskImage(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) {
    return false;
  }
  return _kUnsupportedDiskImageExtensions.contains(
    name.substring(dot + 1).toLowerCase(),
  );
}

class _DownloadTaskFileRow extends StatelessWidget {
  const _DownloadTaskFileRow({required this.file});

  final DownloadTaskFileDto file;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = context.appTextPalette;
    final unsupported = !file.isDir && _isUnsupportedDiskImage(file.name);
    final displayPath = (file.path?.isNotEmpty ?? false)
        ? file.path
        : file.name;
    return Tooltip(
      message: unsupported ? '$displayPath（不支持的媒体格式，无法导入）' : displayPath,
      child: Row(
        children: [
          Icon(
            file.isDir
                ? Icons.folder_outlined
                : unsupported
                ? Icons.dangerous_outlined
                : Icons.insert_drive_file_outlined,
            size: context.appComponentTokens.iconSize3xs,
            color: unsupported
                ? palette.error
                : file.isDir
                ? palette.muted
                : palette.secondary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              file.name,
              key: Key('download-task-file-${file.name}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: unsupported ? AppTextTone.error : AppTextTone.primary,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Text(
            formatFileSize(file.size),
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
