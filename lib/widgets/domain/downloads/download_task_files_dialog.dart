import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/data/download_task_file_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 打开某个下载任务的文件清单：桌面为居中对话框，移动端为底部抽屉。
///
/// 后端从 provider 实时扫描任务源，返回平铺文件列表；这里只读展示，
/// 不做下载或播放。头部以番号为主、影片标题为次。
Future<void> showDownloadTaskFilesDialog({
  required BuildContext context,
  required int taskId,
  required String movieNumber,
  String title = '',
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('download-task-files-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopHeight: MediaQuery.sizeOf(context).height * 0.6,
    builder: (_) => _DownloadTaskFilesDialogBody(
      taskId: taskId,
      movieNumber: movieNumber,
      title: title,
    ),
  );
}

class _DownloadTaskFilesDialogBody extends ConsumerStatefulWidget {
  const _DownloadTaskFilesDialogBody({
    required this.taskId,
    required this.movieNumber,
    required this.title,
  });

  final int taskId;
  final String movieNumber;
  final String title;

  @override
  ConsumerState<_DownloadTaskFilesDialogBody> createState() =>
      _DownloadTaskFilesDialogBodyState();
}

class _DownloadTaskFilesDialogBodyState
    extends ConsumerState<_DownloadTaskFilesDialogBody> {
  late Future<List<DownloadTaskFileDto>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadFiles();
  }

  Future<List<DownloadTaskFileDto>> _loadFiles() {
    return ref.read(downloadsApiProvider).getDownloadTaskFiles(widget.taskId);
  }

  void _retry() {
    setState(() {
      _filesFuture = _loadFiles();
    });
  }

  /// 头部主文案：番号优先，番号缺失时退回影片标题 / 任务名。
  String get _primaryTitle {
    final number = widget.movieNumber.trim();
    return number.isNotEmpty ? number : widget.title.trim();
  }

  /// 次文案：与主文案不同的影片标题；为空或与番号相同时不渲染。
  String? get _secondaryTitle {
    final title = widget.title.trim();
    if (title.isEmpty || title == _primaryTitle) return null;
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final secondaryTitle = _secondaryTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).widgetDownloadFilesTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          _primaryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        if (secondaryTitle != null) ...[
          const SizedBox(height: 2),
          Text(
            secondaryTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
        SizedBox(height: context.appSpacing.lg),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return FutureBuilder<List<DownloadTaskFileDto>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: AppInlineSpinner());
        }
        if (snapshot.hasError) {
          return AppErrorState(
            key: const Key('download-task-files-error'),
            title: AppLocalizations.of(context).baseActionFailed,
            message: apiErrorMessage(
              snapshot.error!,
              fallback: AppLocalizations.of(
                context,
              ).widgetDownloadFilesLoadFailed,
              l10n: AppLocalizations.of(context),
            ),
            retryKey: const Key('download-task-files-retry'),
            onRetry: _retry,
            variant: AppStatePanelVariant.section,
          );
        }
        // 文件按大小降序展示，大文件优先。
        final files = List<DownloadTaskFileDto>.of(
          snapshot.data ?? const <DownloadTaskFileDto>[],
        )..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        if (files.isEmpty) {
          return AppEmptyState(
            message: AppLocalizations.of(context).widgetDownloadFilesEmpty,
          );
        }
        return ListView.separated(
          padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
          itemCount: files.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: context.appColors.divider),
          itemBuilder: (context, index) =>
              _DownloadTaskFileRow(file: files[index]),
        );
      },
    );
  }
}

class _DownloadTaskFileRow extends StatelessWidget {
  const _DownloadTaskFileRow({required this.file});

  final DownloadTaskFileDto file;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final showPath =
        file.relativePath.isNotEmpty && file.relativePath != file.name;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: isMobile ? spacing.md : spacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            file.isVideo
                ? Icons.movie_outlined
                : Icons.insert_drive_file_outlined,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.muted,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: resolveAppTextStyle(
                    context,
                    size: isMobile ? AppTextSize.s14 : AppTextSize.s12,
                    tone: AppTextTone.primary,
                  ),
                ),
                if (showPath) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    file.relativePath,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          Text(
            formatFileSize(file.sizeBytes),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}
