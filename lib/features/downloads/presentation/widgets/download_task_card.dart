import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_delete_dialog.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_task_files_dialog.dart';

/// 下载任务列表中的单张任务卡。
///
/// 行内数据独立订阅：进度 tick 只重建本行，不重建整个列表。
class DownloadTaskCard extends ConsumerWidget {
  const DownloadTaskCard({
    super.key,
    required this.row,
    required this.selection,
  });

  final DownloadTaskRowState row;
  final SelectionController<int> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final taskId = row.task.id;
    // 首屏骨架的占位行在 provider 无 value 时回退到传入的 row。
    final liveRow = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => _rowById(asyncState.value, taskId),
      ),
    );
    final isPending = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => asyncState.value?.isTaskPending(taskId) ?? false,
      ),
    );
    final task = liveRow?.task ?? row.task;
    final clientName = ref.watch(
      downloadTaskCenterProvider.select(
        (asyncState) => asyncState.value?.clientNames[task.clientId],
      ),
    );
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final progress = (liveRow?.progress ?? row.progress).clamp(0.0, 1.0);
    final taskState = liveRow?.state ?? row.state;
    final isImportRunning = task.importStatus == 'running';
    final movieNumber = task.movieNumber;
    final hasMovieNumber = (movieNumber ?? '').isNotEmpty;
    final displayTitle = _resolveDisplayTitle(task);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final selectionMode = selection.active;
    final isSelected = selection.isSelected(taskId);
    final thinCoverUrl = task.movieThinCover?.origin.trim() ?? '';
    final wideCoverUrl = task.movieCover?.origin.trim() ?? '';
    final coverUrl = isMobile && thinCoverUrl.isNotEmpty
        ? thinCoverUrl
        : wideCoverUrl;

    // 骨架态整卡收敛成一块 shimmer 圆角块：进度条 / 状态角标不再透出自有颜色。
    return AppSkeletonUnite(
      borderRadius: context.appRadius.mdBorder,
      child: AppLeftCoverCard(
        key: Key('download-task-${task.id}'),
        coverWidth: componentTokens.downloadTaskCoverWidth,
        bodyMinHeight: componentTokens.downloadTaskCardMinHeight,
        selected: selectionMode && isSelected,
        onTap: selectionMode
            ? () => selection.handleSelectionTap(taskId)
            : null,
        cover: _DownloadTaskCover(
          coverUrl: coverUrl,
          movieNumber: hasMovieNumber ? movieNumber : null,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: selectionMode || !hasMovieNumber
              ? null
              : selection.tapHandler(taskId, () {
                  if (isMobile) {
                    MobileRoutes.movieDetail(
                      movieNumber: movieNumber!,
                    ).push(context);
                    return;
                  }
                  DesktopRoutes.movieDetail(
                    movieNumber: movieNumber!,
                    fallbackPath: desktopDownloadTasksPath,
                  ).push(context);
                }),
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
                AppStatusChip(
                  label: _labelForDownloadState(taskState, l10n),
                  palette: _paletteForDownloadState(taskState),
                  dense: true,
                ),
                Text(
                  formatAppPercent(progress),
                  style: _statTextStyle(context),
                ),
                // 导入 badge 用短标签，完整文案挂 Tooltip 里
                if (task.importStatusLabel.isNotEmpty)
                  Tooltip(
                    message: task.importStatusLabel,
                    child: AppStatusChip(
                      label: _shortImportLabel(
                        task.importStatus,
                        fallback: task.importStatusLabel,
                        l10n: l10n,
                      ),
                      palette: _paletteForImportStatus(task.importStatus),
                      dense: true,
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
                        clientName ??
                            l10n.downloadClientFallbackName(task.clientId),
                        style: _footnoteTextStyle(context),
                      ),
                      if (formatUpdatedAtLabel(task.createdAt) != null)
                        Text(
                          l10n.downloadCreatedAt(
                            formatUpdatedAtLabel(task.createdAt)!,
                          ),
                          style: _footnoteTextStyle(context),
                        ),
                    ],
                  ),
                ),
                if (!selectionMode && task.state == 'completed') ...[
                  AppIconButton(
                    key: Key('download-task-files-${task.id}'),
                    icon: const Icon(Icons.folder_open_rounded),
                    size: AppIconButtonSize.compact,
                    tooltip: l10n.downloadViewFiles,
                    onPressed: () => showDownloadTaskFilesDialog(
                      context: context,
                      taskId: task.id,
                      movieNumber: movieNumber ?? '',
                      title: displayTitle,
                    ),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                ],
                if (!selectionMode && task.canRetriggerImport) ...[
                  AppIconButton(
                    key: Key('download-task-retrigger-import-${task.id}'),
                    icon: const Icon(Icons.refresh_rounded),
                    size: AppIconButtonSize.compact,
                    tooltip: l10n.downloadRetriggerImport,
                    onPressed: isPending
                        ? null
                        : () =>
                              unawaited(_triggerImport(context, ref, task.id)),
                  ),
                  SizedBox(width: context.appSpacing.xs),
                ],
                if (!selectionMode)
                  AppIconButton(
                    key: Key('download-task-delete-${task.id}'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    size: AppIconButtonSize.compact,
                    tooltip: isImportRunning
                        ? l10n.downloadDeleteBlockedImporting
                        : l10n.commonDelete,
                    onPressed: (isPending || isImportRunning)
                        ? null
                        : () => unawaited(_deleteTask(context, ref, task)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 按 task id 取行快照（行卡独立订阅用）；缺失返回 null，调用方回退 prop。
DownloadTaskRowState? _rowById(DownloadTaskCenterState? state, int taskId) {
  final items = state?.paged.items;
  if (items == null) return null;
  for (final row in items) {
    if (row.task.id == taskId) return row;
  }
  return null;
}

String _resolveDisplayTitle(DownloadTaskDto task) {
  final displayName = (task.displayName ?? '').trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }
  final movieTitle = (task.movieTitle ?? '').trim();
  if (movieTitle.isNotEmpty) {
    return movieTitle;
  }
  return task.name.isEmpty ? task.remoteId : task.name;
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
    'downloading' => palette.info,
    'failed' => palette.error,
    'completed' => palette.success,
    _ => colors.borderStrong,
  };
}

/// 导入状态短标签映射。后端 `describe_import_status` 里的完整中文（如
/// "已导入：媒体文件全部成功入库"）在 badge 上过长；这里给出 4 字内的短版，
/// 完整文案通过 Tooltip 保留在 hover 里。
String _shortImportLabel(
  String status, {
  required String fallback,
  required AppLocalizations l10n,
}) {
  return switch (status) {
    'pending' => l10n.downloadImportStatusPending,
    'running' => l10n.downloadImportStatusRunning,
    'completed' => l10n.downloadImportStatusCompleted,
    'failed' => l10n.downloadImportStatusFailed,
    'skipped' => l10n.downloadImportStatusSkipped,
    _ => fallback,
  };
}

Future<void> _triggerImport(
  BuildContext context,
  WidgetRef ref,
  int taskId,
) async {
  try {
    await ref.read(downloadTaskCenterProvider.notifier).triggerImport(taskId);
    if (context.mounted) {
      showToast(
        AppLocalizations.of(context).downloadImportSubmitted,
        tone: AppToastTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.downloadImportSubmitFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}

/// 单条删除保持同步：确认后在弹窗内等待删除接口完成，成功才关闭弹窗。
Future<void> _deleteTask(
  BuildContext context,
  WidgetRef ref,
  DownloadTaskDto task,
) async {
  final notifier = ref.read(downloadTaskCenterProvider.notifier);
  await showDownloadTaskDeleteDialog(
    context,
    tasks: [task],
    onConfirm: (deleteFiles) =>
        notifier.deleteTask(task.id, deleteFiles: deleteFiles),
  );
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
        label: AppLocalizations.of(
          context,
        ).downloadViewMovieDetails(movieNumber ?? ''),
        child: Material(
          color: Colors.transparent,
          child: AppInteractiveSurface(
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

String _labelForDownloadState(String state, AppLocalizations l10n) {
  return switch (state) {
    'downloading' => l10n.downloadStateDownloading,
    'queued' => l10n.downloadStateQueued,
    'completed' => l10n.downloadStateCompleted,
    'failed' => l10n.downloadStateFailed,
    _ => state.isEmpty ? l10n.commonUnknown : state,
  };
}

AppStatusChipPalette _paletteForDownloadState(String state) {
  return switch (state) {
    'downloading' => AppStatusChipPalette.forSemantic(
      AppStatusSemantic.inProgress,
      icon: Icons.downloading_rounded,
    ),
    'queued' => AppStatusChipPalette.forSemantic(AppStatusSemantic.queued),
    'completed' => AppStatusChipPalette.forSemantic(AppStatusSemantic.success),
    'failed' => AppStatusChipPalette.forSemantic(AppStatusSemantic.error),
    _ => AppStatusChipPalette.neutral(),
  };
}

AppStatusChipPalette _paletteForImportStatus(String state) {
  return switch (state) {
    'running' => AppStatusChipPalette.forSemantic(
      AppStatusSemantic.inProgress,
      icon: Icons.sync_rounded,
    ),
    'completed' => AppStatusChipPalette.forSemantic(AppStatusSemantic.success),
    'failed' => AppStatusChipPalette.forSemantic(AppStatusSemantic.error),
    'pending' => AppStatusChipPalette.forSemantic(AppStatusSemantic.queued),
    'skipped' => AppStatusChipPalette.muted(icon: Icons.skip_next_rounded),
    _ => AppStatusChipPalette.neutral(),
  };
}
