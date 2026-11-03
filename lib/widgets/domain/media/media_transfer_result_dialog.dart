import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_transfer_dto.dart';
import 'package:sakuramedia/features/media/data/media_transfer_reason_descriptions.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 打开一次媒体迁移任务的逐文件结果。
///
/// 未成功项排在成功项之前；每一行仍带细分状态徽标，避免两组合并后丢失
/// “失败 / 源文件待确认 / 已跳过 / 未执行”的差异。
Future<void> showMediaTransferResultDialog({
  required BuildContext context,
  required int taskRunId,
  required String taskName,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('media-transfer-result-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopHeight: MediaQuery.sizeOf(context).height * 0.72,
    builder: (_) => _MediaTransferResultDialogBody(
      taskRunId: taskRunId,
      taskName: taskName,
    ),
  );
}

class _MediaTransferResultDialogBody extends ConsumerStatefulWidget {
  const _MediaTransferResultDialogBody({
    required this.taskRunId,
    required this.taskName,
  });

  final int taskRunId;
  final String taskName;

  @override
  ConsumerState<_MediaTransferResultDialogBody> createState() =>
      _MediaTransferResultDialogBodyState();
}

class _MediaTransferResultDialogBodyState
    extends ConsumerState<_MediaTransferResultDialogBody> {
  late Future<List<MediaTransferFileDto>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadFiles();
  }

  Future<List<MediaTransferFileDto>> _loadFiles() {
    return ref
        .read(mediaApiProvider)
        .getMediaTransferFiles(taskRunId: widget.taskRunId);
  }

  void _retry() {
    setState(() {
      _filesFuture = _loadFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaTransferFileDto>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        final files = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).widgetMediaTransferResultTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.xs),
            Text(
              _subtitle(files),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
            Expanded(child: _buildContent(snapshot)),
          ],
        );
      },
    );
  }

  String _subtitle(List<MediaTransferFileDto>? files) {
    final l10n = AppLocalizations.of(context);
    final taskName = widget.taskName.trim();
    if (files == null) {
      return taskName;
    }
    final succeeded = files.where((item) => item.status.isTransferred).length;
    final unsuccessful = files.length - succeeded;
    return <String>[
      if (taskName.isNotEmpty) taskName,
      l10n.widgetMediaTransferSummarySucceeded(succeeded),
      l10n.widgetMediaTransferSummaryUnsuccessful(unsuccessful),
    ].join(' · ');
  }

  Widget _buildContent(AsyncSnapshot<List<MediaTransferFileDto>> snapshot) {
    final l10n = AppLocalizations.of(context);
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: AppInlineSpinner());
    }
    if (snapshot.hasError) {
      return AppEmptyState(
        message: apiErrorMessage(
          snapshot.error!,
          fallback: l10n.widgetMediaTransferFilesLoadFailed,
          l10n: l10n,
        ),
        onRetry: _retry,
        retryKey: const Key('media-transfer-result-retry'),
      );
    }
    final files = snapshot.data ?? const <MediaTransferFileDto>[];
    if (files.isEmpty) {
      return AppEmptyState(message: l10n.widgetMediaTransferFilesEmpty);
    }

    final unsuccessful = files
        .where((item) => !item.status.isTransferred)
        .toList(growable: false);
    final successful = files
        .where((item) => item.status.isTransferred)
        .toList(growable: false);
    final entries = <_ResultListEntry>[
      if (unsuccessful.isNotEmpty)
        _ResultListEntry.section(
          l10n.widgetMediaTransferUnsuccessfulHeader(unsuccessful.length),
        ),
      ...unsuccessful.map(_ResultListEntry.file),
      if (successful.isNotEmpty)
        _ResultListEntry.section(
          l10n.widgetMediaTransferSuccessfulHeader(successful.length),
        ),
      ...successful.map(_ResultListEntry.file),
    ];

    return ListView.builder(
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final file = entry.file;
        if (file == null) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              context.appSpacing.xs,
              index == 0 ? 0 : context.appSpacing.lg,
              context.appSpacing.xs,
              context.appSpacing.sm,
            ),
            child: Text(
              entry.title!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          );
        }
        final next = index + 1 < entries.length ? entries[index + 1] : null;
        return _MediaTransferFileRow(
          file: file,
          showDivider: next?.file != null,
        );
      },
    );
  }
}

class _ResultListEntry {
  const _ResultListEntry.section(this.title) : file = null;
  const _ResultListEntry.file(this.file) : title = null;

  final String? title;
  final MediaTransferFileDto? file;
}

class _MediaTransferFileRow extends StatelessWidget {
  const _MediaTransferFileRow({required this.file, required this.showDivider});

  final MediaTransferFileDto file;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final subtitle = _subtitle(l10n);
    final statusLabel = _statusLabel(l10n);
    final statusTone = _statusTone();
    final fileName = file.fileName.trim().isEmpty
        ? l10n.widgetMediaTransferFileFallback(file.mediaId)
        : file.fileName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.md,
            vertical: context.appSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                _statusIcon(file.status),
                size: context.appComponentTokens.iconSizeSm,
                color: _statusIconColor(context),
              ),
              SizedBox(width: context.appSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.appSpacing.sm),
              AppBadge(
                label: statusLabel,
                tone: statusTone,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: colors.divider),
      ],
    );
  }

  String? _subtitle(AppLocalizations l10n) {
    final parts = <String>[
      if ((file.movieNumber ?? '').trim().isNotEmpty) file.movieNumber!.trim(),
      if ((file.reasonCode ?? '').trim().isNotEmpty)
        describeMediaTransferReason(file.reasonCode!, l10n),
      if (file.sizeBytes > 0) formatFileSize(file.sizeBytes),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (file.status) {
      MediaTransferFileStatus.transferred =>
        l10n.widgetMediaTransferStatusTransferred,
      MediaTransferFileStatus.failed => l10n.widgetMediaTransferStatusFailed,
      MediaTransferFileStatus.cleanupIncomplete =>
        l10n.widgetMediaTransferStatusCleanupIncomplete,
      MediaTransferFileStatus.skipped => l10n.widgetMediaTransferStatusSkipped,
      MediaTransferFileStatus.unexecuted || MediaTransferFileStatus.pending =>
        l10n.widgetMediaTransferStatusUnexecuted,
    };
  }

  AppBadgeTone _statusTone() {
    return switch (file.status) {
      MediaTransferFileStatus.transferred => AppBadgeTone.success,
      MediaTransferFileStatus.failed => AppBadgeTone.error,
      MediaTransferFileStatus.cleanupIncomplete => AppBadgeTone.warning,
      _ => AppBadgeTone.neutral,
    };
  }

  Color _statusIconColor(BuildContext context) {
    return switch (file.status) {
      MediaTransferFileStatus.transferred => context.appTextPalette.success,
      MediaTransferFileStatus.failed => context.appTextPalette.error,
      MediaTransferFileStatus.cleanupIncomplete =>
        context.appTextPalette.warning,
      _ => context.appTextPalette.muted,
    };
  }

  static IconData _statusIcon(MediaTransferFileStatus status) {
    return switch (status) {
      MediaTransferFileStatus.transferred => Icons.check_circle_outline_rounded,
      MediaTransferFileStatus.failed => Icons.error_outline_rounded,
      MediaTransferFileStatus.cleanupIncomplete => Icons.warning_amber_rounded,
      MediaTransferFileStatus.skipped => Icons.remove_circle_outline_rounded,
      MediaTransferFileStatus.unexecuted ||
      MediaTransferFileStatus.pending => Icons.schedule_rounded,
    };
  }
}
