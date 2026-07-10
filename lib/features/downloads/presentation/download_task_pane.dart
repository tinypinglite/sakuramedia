import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/format/transfer_speed.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_center_controller.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 构建「下载任务」Tab 的 sliver 列表。
///
/// 与 [buildResourceTaskSlivers] 对齐的纯函数风格：调用方负责把返回的 slivers 放进
/// 外层 `CustomScrollView`。
List<Widget> buildDownloadTaskSlivers({
  required BuildContext context,
  required DownloadTaskCenterController controller,
}) {
  if (controller.isInitialLoading) {
    return const <Widget>[SliverToBoxAdapter(child: _DownloadInitialLoading())];
  }
  if (controller.initialErrorMessage != null) {
    return <Widget>[
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: controller.initialErrorMessage!,
          onRetry: () => controller.retryInitialize(),
        ),
      ),
    ];
  }

  final slivers = <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: _DownloadClientSpeedBar(controller: controller),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.lg),
        child: _DownloadFilterBar(controller: controller),
      ),
    ),
    // 筛选切换等 reload 场景下顶部一条薄进度条作为轻量加载反馈。
    // 保留筛选栏 + 速度栏 + 旧 items 不动，避免整页 spinner 让筛选栏消失/重建
    // 造成的视觉闪烁与 AppSelectField 内部动画/焦点丢失。
    if (controller.isReloading)
      SliverToBoxAdapter(
        key: const Key('download-tasks-reloading-indicator'),
        child: Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: const LinearProgressIndicator(minHeight: 2),
        ),
      ),
  ];

  if (controller.items.isEmpty) {
    // 有筛选时给一个可以「清除筛选」的重试入口，避免用户困惑「明明有任务却看不到」。
    final hasFilter = !controller.filter.isDefault;
    slivers.add(
      SliverToBoxAdapter(
        child: AppEmptyState(
          message: hasFilter ? '没有符合筛选条件的下载任务' : '暂无下载任务',
          icon: hasFilter ? Icons.search_off_rounded : Icons.download_outlined,
          onRetry:
              hasFilter
                  ? () =>
                      controller.applyFilter(DownloadTaskFilterState.initial)
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
        final row = controller.items[index];
        final isLast = index == controller.items.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.md),
          child: RepaintBoundary(
            child: _DownloadTaskCard(controller: controller, row: row),
          ),
        );
      }, childCount: controller.items.length),
    ),
  );

  if (controller.hasMore || controller.loadMoreErrorMessage != null) {
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: controller.isLoadingMore,
              errorMessage: controller.loadMoreErrorMessage,
              onRetry: controller.loadMore,
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
  const _DownloadClientSpeedBar({required this.controller});

  final DownloadTaskCenterController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final transfers =
        controller.clientTransfers.values.toList()
          ..sort((a, b) => a.clientId.compareTo(b.clientId));
    final hasAnyLiveData = transfers.isNotEmpty;
    final totalDown = controller.totalDownloadSpeedBytes;
    final totalUp = controller.totalUploadSpeedBytes;

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
                for (final transfer in transfers)
                  _ClientTransferPill(
                    controller: controller,
                    transfer: transfer,
                  ),
              ],
            ),
          ),
          if (controller.streamState != DownloadTaskStreamState.idle) ...[
            SizedBox(width: context.appSpacing.sm),
            _DownloadStreamBadge(state: controller.streamState),
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

class _ClientTransferPill extends StatelessWidget {
  const _ClientTransferPill({required this.controller, required this.transfer});

  final DownloadTaskCenterController controller;
  final DownloadClientTransferState transfer;

  @override
  Widget build(BuildContext context) {
    final name = controller.clientNameOf(transfer.clientId);
    if (!transfer.isAvailable) {
      return Tooltip(
        message: transfer.unavailableMessage ?? '客户端不可用',
        child: AppBadge(
          key: Key('download-client-status-${transfer.clientId}'),
          label: '$name · 不可用',
          tone: AppBadgeTone.error,
          size: AppBadgeSize.compact,
        ),
      );
    }
    final label =
        '$name · ↓${formatTransferSpeed(transfer.downloadSpeedBytes)} · ↑${formatTransferSpeed(transfer.uploadSpeedBytes)}';
    return AppBadge(
      key: Key('download-client-status-${transfer.clientId}'),
      label: label,
      tone: AppBadgeTone.neutral,
      size: AppBadgeSize.compact,
    );
  }
}

class _DownloadStreamBadge extends StatelessWidget {
  const _DownloadStreamBadge({required this.state});

  final DownloadTaskStreamState state;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (state) {
      DownloadTaskStreamState.live => ('实时', AppBadgeTone.success),
      DownloadTaskStreamState.connecting => ('连接中', AppBadgeTone.neutral),
      DownloadTaskStreamState.reconnecting => ('重连中', AppBadgeTone.warning),
      DownloadTaskStreamState.polling => ('轮询', AppBadgeTone.info),
      DownloadTaskStreamState.idle => ('未连接', AppBadgeTone.neutral),
    };
    return AppBadge(
      key: const Key('download-task-stream-badge'),
      label: label,
      tone: tone,
      size: AppBadgeSize.compact,
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({required this.controller, required this.row});

  final DownloadTaskCenterController controller;
  final DownloadTaskRowState row;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final task = row.task;
    final live = row.live;
    final progress = row.progress.clamp(0.0, 1.0);
    final downloadState = row.downloadState;
    final isPending = controller.isTaskPending(task.id);
    final isImportRunning = task.importStatus == 'running';
    final movieNumber = task.movieNumber;
    final hasMovieNumber = (movieNumber ?? '').isNotEmpty;
    final displayTitle = _resolveDisplayTitle(task);
    final coverUrl = task.movieCover?.bestAvailableUrl ?? '';

    return Container(
      key: Key('download-task-${task.id}'),
      width: double.infinity,
      // clipBehavior 让内容按 borderRadius 裁剪：封面直接贴到左边框内侧，无缝隙。
      // border 由 decoration 绘制在容器外围，clip 区域是 border 内侧——封面不会覆盖 border。
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      // 用 Stack + Positioned 布局：Row(stretch) 需要先算 Row 高度 = max children
      // heights，但 MaskedImage 内 LayoutBuilder 在 loose height 下 layout 依赖图片
      // 异步加载完成——会 race。Stack 让 non-positioned 子（右侧内容）决定高度，
      // Positioned 子直接拿 tight (width × Stack 高度) 约束，MaskedImage 一步到位。
      // 右侧内容决定 Stack 高度，最小高度由下载任务卡 token 保证。
      child: Stack(
        children: [
          // 右侧信息区——非 Positioned 子，决定 Stack 高度。
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: componentTokens.downloadTaskCoverWidth,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: componentTokens.downloadTaskCardMinHeight,
              ),
              child: Padding(
                padding: EdgeInsets.all(context.appSpacing.lg),
                child: Column(
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
                        if (live != null && live.totalSizeBytes > 0)
                          Text(
                            '${formatFileSize(live.downloadedBytes)} / ${formatFileSize(live.totalSizeBytes)}',
                            style: _statTextStyle(context),
                          ),
                        if (live != null && downloadState == 'downloading') ...[
                          Text(
                            '↓${formatTransferSpeed(live.downloadSpeedBytes)}',
                            style: _statTextStyle(context),
                          ),
                          Text(
                            '↑${formatTransferSpeed(live.uploadedSpeedBytes)}',
                            style: _statTextStyle(context),
                          ),
                        ],
                        // 做种态：下载已完成，只展示上传速度（"贡献速率"）
                        if (live != null && downloadState == 'seeding')
                          Text(
                            '↑${formatTransferSpeed(live.uploadedSpeedBytes)}',
                            style: _statTextStyle(context),
                          ),
                        if (live?.etaSeconds != null &&
                            (live?.etaSeconds ?? 0) > 0)
                          Text(
                            '剩余 ${formatMediaDurationLabel(live!.etaSeconds!)}',
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
                                controller.clientNameOf(task.clientId),
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
                        // 已完成不显示暂停/恢复；做种态可以暂停（停止上传）。
                        if (downloadState == 'paused')
                          AppIconButton(
                            key: Key('download-task-resume-${task.id}'),
                            icon: const Icon(Icons.play_arrow_rounded),
                            tooltip: '恢复',
                            onPressed:
                                isPending
                                    ? null
                                    : () =>
                                        _resume(context, controller, task.id),
                          )
                        else if (downloadState != 'completed')
                          AppIconButton(
                            key: Key('download-task-pause-${task.id}'),
                            icon: const Icon(Icons.pause_rounded),
                            tooltip: '暂停',
                            onPressed:
                                isPending
                                    ? null
                                    : () =>
                                        _pause(context, controller, task.id),
                          ),
                        if (downloadState != 'completed')
                          SizedBox(width: context.appSpacing.xs),
                        AppIconButton(
                          key: Key('download-task-delete-${task.id}'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: isImportRunning ? '任务正在导入，无法删除' : '删除',
                          onPressed:
                              (isPending || isImportRunning)
                                  ? null
                                  : () =>
                                      _confirmDelete(context, controller, task),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 封面贴合左侧，高度由 Stack 约束为整张卡片高度。
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: componentTokens.downloadTaskCoverWidth,
            child: _DownloadTaskCover(
              coverUrl: coverUrl,
              movieNumber: hasMovieNumber ? movieNumber : null,
              onTap:
                  hasMovieNumber
                      ? () => context.pushDesktopMovieDetail(
                        movieNumber: movieNumber!,
                        fallbackPath: desktopActivityPath,
                      )
                      : null,
            ),
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

Future<void> _pause(
  BuildContext context,
  DownloadTaskCenterController controller,
  int taskId,
) async {
  try {
    await controller.pauseTask(taskId);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showToast(_downloadErrorMessage(error, fallback: '暂停失败'));
  }
}

Future<void> _resume(
  BuildContext context,
  DownloadTaskCenterController controller,
  int taskId,
) async {
  try {
    await controller.resumeTask(taskId);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    showToast(_downloadErrorMessage(error, fallback: '恢复失败'));
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  DownloadTaskCenterController controller,
  DownloadTaskDto task,
) async {
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
      onChanged: (value) => deleteFiles = value,
    ),
    onConfirm: () async {
      try {
        await controller.deleteTask(task.id, deleteFiles: deleteFiles);
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
    }
  }
  return apiErrorMessage(error, fallback: fallback);
}

class _DeleteFilesCheckbox extends StatefulWidget {
  const _DeleteFilesCheckbox({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  State<_DeleteFilesCheckbox> createState() => _DeleteFilesCheckboxState();
}

class _DeleteFilesCheckboxState extends State<_DeleteFilesCheckbox> {
  bool _deleteFiles = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _deleteFiles = !_deleteFiles;
        });
        widget.onChanged(_deleteFiles);
      },
      borderRadius: context.appRadius.smBorder,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              key: const Key('download-task-delete-files-checkbox'),
              value: _deleteFiles,
              onChanged: (value) {
                setState(() {
                  _deleteFiles = value ?? false;
                });
                widget.onChanged(_deleteFiles);
              },
            ),
            SizedBox(width: context.appSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '同时删除下载器里的种子文件',
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
    'seeding' => '做种中',
    'completed' => '已完成',
    'paused' => '已暂停',
    'failed' => '失败',
    'stalled' => '等待资源',
    'checking' => '校验中',
    'queued' => '排队中',
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
    'checking' => AppBadgeTone.info,
    'queued' => AppBadgeTone.neutral,
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
/// 遵循「筛选状态驱动」范式：所有变更走 `controller.applyFilter(...)`，控制器内部
/// reload + 重开 SSE，并按新 filter 拼后端查询参数（movie_number / download_state /
/// client_id）。搜索输入沿用项目其它筛选栏习惯——**不做打字 debounce**，仅回车/失焦提交。
class _DownloadFilterBar extends StatefulWidget {
  const _DownloadFilterBar({required this.controller});

  final DownloadTaskCenterController controller;

  @override
  State<_DownloadFilterBar> createState() => _DownloadFilterBarState();
}

class _DownloadFilterBarState extends State<_DownloadFilterBar> {
  late final TextEditingController _searchController;
  String _attachedFilterSearch = '';

  @override
  void initState() {
    super.initState();
    final initialSearch = widget.controller.filter.search;
    _attachedFilterSearch = initialSearch;
    _searchController = TextEditingController(text: initialSearch);
  }

  @override
  void didUpdateWidget(covariant _DownloadFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若外部通过其它入口（比如「清除筛选」按钮）改了 filter.search，同步进输入框；
    // 但用户正在输入时（textController.text != _attachedFilterSearch）避免打断。
    final currentSearch = widget.controller.filter.search;
    if (currentSearch != _attachedFilterSearch &&
        currentSearch != _searchController.text) {
      _searchController.text = currentSearch;
    }
    _attachedFilterSearch = currentSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String value) async {
    final next = widget.controller.filter.copyWith(search: value.trim());
    _attachedFilterSearch = next.search;
    await widget.controller.applyFilter(next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    // reload 时也 disable，防止用户在加载中再点击导致排队多次请求。
    final isBusy = controller.isInitialLoading || controller.isReloading;
    final clientOptions = controller.clientOptions;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthLg,
          child: AppTextField(
            fieldKey: const Key('download-filter-search'),
            controller: _searchController,
            hintText: '按番号搜索',
            textInputAction: TextInputAction.search,
            onFieldSubmitted: _submitSearch,
            enabled: !isBusy,
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<DownloadTaskStateFilter>(
            key: const Key('download-filter-state'),
            value: controller.filter.stateFilter,
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
            onChanged:
                isBusy
                    ? null
                    : (value) => controller.applyFilter(
                      controller.filter.copyWith(
                        stateFilter: value ?? DownloadTaskStateFilter.all,
                      ),
                    ),
          ),
        ),
        if (clientOptions.length >= 2)
          SizedBox(
            width: layoutTokens.filterFieldWidthMd,
            child: AppSelectField<int?>(
              key: const Key('download-filter-client'),
              value: controller.filter.clientId,
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
              onChanged:
                  isBusy
                      ? null
                      : (value) => controller.applyFilter(
                        controller.filter.copyWith(clientId: value),
                      ),
            ),
          ),
      ],
    );
  }
}
