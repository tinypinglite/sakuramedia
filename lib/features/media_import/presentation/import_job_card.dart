import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/media_import/data/failure_reason_descriptions.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 导入作业卡片：JAV 与 PornBox 两类导入作业共用。
///
/// 数据通过 [ImportJobCardData] / [ImportJobCardDetailData] 抽象传入，
/// 卡片本身不感知具体作业类型。
class ImportJobCard extends StatelessWidget {
  const ImportJobCard({
    super.key,
    required this.job,
    required this.taskRun,
    required this.expanded,
    required this.detail,
    required this.isDetailLoading,
    required this.detailError,
    required this.onToggle,
    required this.onRetryAll,
    required this.onRetryFile,
    required this.onDeleteFile,
    required this.onRenameFile,
    required this.onReloadDetail,
  });

  final ImportJobCardData job;
  final TaskRunDto? taskRun;
  final bool expanded;
  final ImportJobCardDetailData? detail;
  final bool isDetailLoading;
  final String? detailError;
  final VoidCallback onToggle;
  final VoidCallback onRetryAll;
  final void Function(String path) onRetryFile;
  final void Function(String path) onDeleteFile;
  final void Function(String path, String currentName) onRenameFile;
  final VoidCallback onReloadDetail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final liveRun = taskRun;
    final showProgress = liveRun != null && liveRun.isActive;

    return AppContentCard(
      title: _sourceName(job.sourcePath),
      headerBottomSpacing: spacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.sourcePath,
            key: Key('media-import-job-path-${job.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusBadge(state: job.state),
              _MetaChip(
                icon: Icons.swap_horiz_rounded,
                label: job.transferMode.label,
              ),
              _MetaChip(
                icon: Icons.check_circle_outline_rounded,
                label: '导入 ${job.importedCount}',
              ),
              _MetaChip(
                icon: Icons.skip_next_rounded,
                label: '跳过 ${job.skippedCount}',
              ),
              _MetaChip(
                icon: Icons.error_outline_rounded,
                label: '失败 ${job.failedCount}',
              ),
            ],
          ),
          if (showProgress) ...[
            SizedBox(height: spacing.md),
            _ProgressBar(taskRun: liveRun),
          ],
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  _timeText(),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ),
              if (job.failedCount > 0 || job.skippedCount > 0)
                AppButton(
                  key: Key('media-import-job-toggle-${job.id}'),
                  label: expanded ? '收起失败/跳过文件' : '查看失败/跳过文件',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.ghost,
                  onPressed: onToggle,
                ),
            ],
          ),
          if (expanded) ...[
            SizedBox(height: spacing.md),
            _buildDetail(context),
          ],
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    if (isDetailLoading && detail == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
          child: SizedBox(
            width: context.appComponentTokens.movieCardLoaderSize,
            height: context.appComponentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }
    if (detailError != null && detail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detailError!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            label: '重试',
            size: AppButtonSize.small,
            onPressed: onReloadDetail,
          ),
        ],
      );
    }
    final loaded = detail;
    if (loaded == null || loaded.failedFiles.isEmpty) {
      return Text(
        '没有失败/跳过文件记录。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        ),
      );
    }

    final actionable = loaded.actionableFailedFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actionable.isNotEmpty && loaded.isTerminal) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              key: Key('media-import-retry-all-${job.id}'),
              label: '重导全部失败（${actionable.length}）',
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
              onPressed: onRetryAll,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
        ],
        ...loaded.failedFiles.map(
          (file) => Padding(
            padding: EdgeInsets.only(bottom: context.appSpacing.sm),
            child: _FailedFileRow(
              file: file,
              canAct: file.isActionable && loaded.isTerminal,
              onRetry: () => onRetryFile(file.path),
              onDelete: () => onDeleteFile(file.path),
              onRename: () => onRenameFile(file.path, _sourceName(file.path)),
            ),
          ),
        ),
      ],
    );
  }

  String _timeText() {
    final createdText = formatUpdatedAtLabel(job.createdAt) ?? '未知';
    final finishedText = formatUpdatedAtLabel(job.finishedAt);
    if (finishedText != null) {
      return '创建于 $createdText · 完成于 $finishedText';
    }
    return '创建于 $createdText';
  }

  String _sourceName(String path) {
    final normalized = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final index = normalized.lastIndexOf('/');
    final name = index >= 0 ? normalized.substring(index + 1) : normalized;
    return name.isEmpty ? path : name;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.taskRun});

  final TaskRunDto taskRun;

  @override
  Widget build(BuildContext context) {
    final value = taskRun.progressValue;
    final text = taskRun.progressText;
    final counts = taskRun.hasDeterminateProgress
        ? '${taskRun.progressCurrent}/${taskRun.progressTotal}'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: context.appRadius.smBorder,
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: context.appColors.surfaceMuted,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          [
            if (counts != null) counts,
            if (text != null && text.trim().isNotEmpty) text,
          ].join(' · ').trim().isEmpty
              ? '导入中…'
              : [
                  if (counts != null) counts,
                  if (text != null && text.trim().isNotEmpty) text,
                ].join(' · '),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = context.appTextPalette;
    final (label, background, foreground) = switch (state) {
      'completed' => ('已完成', colors.successSurface, palette.success),
      'failed' => ('失败', colors.errorSurface, palette.error),
      'running' => ('导入中', colors.infoSurface, palette.info),
      'pending' => ('等待中', colors.infoSurface, palette.info),
      _ => (state.isEmpty ? '未知' : state, colors.surfaceMuted, palette.muted),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.semibold,
        ).copyWith(color: foreground),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: context.appComponentTokens.iconSizeXs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: context.appSpacing.xs),
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}

class _FailedFileRow extends StatelessWidget {
  const _FailedFileRow({
    required this.file,
    required this.canAct,
    required this.onRetry,
    required this.onDelete,
    required this.onRename,
  });

  final FailedFileDto file;
  final bool canAct;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  file.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              _KindTag(kind: file.kind),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            file.detail.isNotEmpty
                ? '${describeFailureReason(file.reason)} · ${file.detail}'
                : describeFailureReason(file.reason),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          if (canAct) ...[
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.xs,
              children: [
                AppButton(
                  label: '重导',
                  size: AppButtonSize.xSmall,
                  onPressed: onRetry,
                ),
                AppButton(
                  label: '重命名',
                  size: AppButtonSize.xSmall,
                  onPressed: onRename,
                ),
                AppButton(
                  label: '删除',
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.danger,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KindTag extends StatelessWidget {
  const _KindTag({required this.kind});

  final FailedFileKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      FailedFileKind.file => '可处理',
      FailedFileKind.skipped => '已跳过',
      FailedFileKind.warning => '告警',
      FailedFileKind.job => '任务级',
    };
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: kind == FailedFileKind.file
            ? AppTextTone.accent
            : AppTextTone.muted,
      ),
    );
  }
}
