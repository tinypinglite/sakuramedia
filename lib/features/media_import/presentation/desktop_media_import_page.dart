import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/media_import_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class DesktopMediaImportPage extends StatefulWidget {
  const DesktopMediaImportPage({super.key});

  @override
  State<DesktopMediaImportPage> createState() => _DesktopMediaImportPageState();
}

class _DesktopMediaImportPageState extends State<DesktopMediaImportPage> {
  late final MediaImportController _controller;
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _controller = MediaImportController(
      mediaImportApi: context.read<MediaImportApi>(),
      activityApi: context.read<ActivityApi>(),
    );
    _scrollController.addListener(_handleScroll);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_controller.loadMore());
    }
  }

  Future<void> _openCreateDialog() async {
    final request = await showDirectoryPickerDialog(context);
    if (request == null || !mounted) {
      return;
    }
    final error = await _controller.triggerImport(
      libraryId: request.libraryId,
      sourcePath: request.sourcePath,
      transferMode: request.transferMode,
    );
    if (!mounted) {
      return;
    }
    showToast(error ?? '导入任务已提交，可在下方查看进度');
  }

  void _toggleExpanded(int jobId) {
    setState(() {
      if (_expanded.contains(jobId)) {
        _expanded.remove(jobId);
      } else {
        _expanded.add(jobId);
        unawaited(_controller.ensureDetail(jobId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppPageFrame(
          title: '',
          scrollController: _scrollController,
          child: Column(
            key: const Key('media-import-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                isLoading: _controller.isInitialLoading,
                onCreate: () => unawaited(_openCreateDialog()),
                onRefresh: () => unawaited(_controller.refresh()),
              ),
              SizedBox(height: context.appSpacing.lg),
              _buildBody(context),
              if (_controller.jobs.isNotEmpty &&
                  (_controller.isLoadingMore ||
                      _controller.loadMoreError != null)) ...[
                SizedBox(height: context.appSpacing.lg),
                AppPagedLoadMoreFooter(
                  isLoading: _controller.isLoadingMore,
                  errorMessage: _controller.loadMoreError,
                  onRetry: () => unawaited(_controller.loadMore()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading) {
      return AppContentCard(
        title: '正在加载',
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.appLayoutTokens.emptySectionVerticalPadding,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (_controller.initialError != null) {
      return AppContentCard(
        title: '加载失败',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppEmptyState(message: _controller.initialError!),
            SizedBox(height: context.appSpacing.lg),
            Center(
              child: AppButton(
                key: const Key('media-import-initial-retry-button'),
                label: '重试',
                variant: AppButtonVariant.primary,
                onPressed: () => unawaited(_controller.loadFirstPage()),
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.jobs.isEmpty) {
      return const AppEmptyState(message: '还没有导入作业。点击「新建导入」从后端目录选择媒体导入。');
    }

    return Column(
      children: _controller.jobs
          .map(
            (job) => Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.md),
              child: _ImportJobCard(
                job: job,
                taskRun: _controller.taskRunFor(job.taskRunId),
                expanded: _expanded.contains(job.id),
                detail: _controller.detailFor(job.id),
                isDetailLoading: _controller.isDetailLoading(job.id),
                detailError: _controller.detailError(job.id),
                dateFormat: _dateFormat,
                onToggle: () => _toggleExpanded(job.id),
                onRetryAll: () => _retryAll(job),
                onRetryFile: (path) => _retryFiles(job, <String>[path]),
                onDeleteFile: (path) => _deleteFile(job, path),
                onRenameFile: (path, name) => _renameFile(job, path, name),
                onReloadDetail: () =>
                    unawaited(_controller.ensureDetail(job.id, force: true)),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _retryAll(ImportJobListItemDto job) async {
    final error = await _controller.retryFailedFiles(job.id);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  Future<void> _retryFiles(ImportJobListItemDto job, List<String> files) async {
    final error = await _controller.retryFailedFiles(job.id, files: files);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  Future<void> _deleteFile(ImportJobListItemDto job, String path) async {
    final confirmed = await _confirmDelete(path);
    if (!mounted || confirmed != true) {
      return;
    }
    final error = await _controller.deleteFailedFile(job.id, path: path);
    if (!mounted) {
      return;
    }
    showToast(error ?? '源文件已删除');
  }

  Future<void> _renameFile(
    ImportJobListItemDto job,
    String path,
    String currentName,
  ) async {
    final newName = await _promptRename(currentName);
    if (!mounted || newName == null || newName.trim().isEmpty) {
      return;
    }
    final error = await _controller.renameFailedFile(
      job.id,
      path: path,
      newName: newName.trim(),
    );
    if (!mounted) {
      return;
    }
    showToast(error ?? '已重命名');
  }

  Future<bool?> _confirmDelete(String path) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('media-import-delete-confirm-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '删除源文件',
              style: resolveAppTextStyle(dialogContext, size: AppTextSize.s18),
            ),
            SizedBox(height: dialogContext.appSpacing.lg),
            Text('确认删除该失败源文件？该操作不可恢复。\n\n$path'),
            SizedBox(height: dialogContext.appSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                SizedBox(width: dialogContext.appSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '删除',
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRename(String currentName) {
    final textController = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('media-import-rename-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '重命名源文件',
              style: resolveAppTextStyle(dialogContext, size: AppTextSize.s18),
            ),
            SizedBox(height: dialogContext.appSpacing.lg),
            AppTextField(
              fieldKey: const Key('media-import-rename-field'),
              controller: textController,
              label: '新文件名',
              hintText: '例如 ABP-123.mp4',
            ),
            SizedBox(height: dialogContext.appSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                SizedBox(width: dialogContext.appSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '确认',
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(textController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(textController.dispose);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isLoading,
    required this.onCreate,
    required this.onRefresh,
  });

  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: '媒体导入',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '从后端白名单目录中选择已有媒体并导入到媒体库。导入在后台运行，可在此查看实时进度与失败文件处理。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          AppButton(
            key: const Key('media-import-refresh-button'),
            label: '刷新',
            onPressed: onRefresh,
          ),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-create-button'),
            label: '新建导入',
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            onPressed: isLoading ? null : onCreate,
          ),
        ],
      ),
    );
  }
}

class _ImportJobCard extends StatelessWidget {
  const _ImportJobCard({
    required this.job,
    required this.taskRun,
    required this.expanded,
    required this.detail,
    required this.isDetailLoading,
    required this.detailError,
    required this.dateFormat,
    required this.onToggle,
    required this.onRetryAll,
    required this.onRetryFile,
    required this.onDeleteFile,
    required this.onRenameFile,
    required this.onReloadDetail,
  });

  final ImportJobListItemDto job;
  final TaskRunDto? taskRun;
  final bool expanded;
  final ImportJobDto? detail;
  final bool isDetailLoading;
  final String? detailError;
  final DateFormat dateFormat;
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
              if (job.failedCount > 0)
                AppButton(
                  key: Key('media-import-job-toggle-${job.id}'),
                  label: expanded ? '收起失败文件' : '查看失败文件',
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
        '没有失败文件记录。',
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
    final created = job.createdAt;
    final finished = job.finishedAt;
    final createdText =
        created == null ? '未知' : dateFormat.format(created.toLocal());
    if (finished != null) {
      return '创建于 $createdText · 完成于 ${dateFormat.format(finished.toLocal())}';
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
            file.detail.isNotEmpty ? '${file.reason} · ${file.detail}' : file.reason,
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
