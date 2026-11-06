import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';

/// 弹出切片标题输入对话框并执行同步切片创建。
///
/// 成功返回新建（或命中去重的）切片；用户取消或切片超时返回 `null`。
Future<MediaClipDto?> showCreateClipDialog(
  BuildContext context, {
  required int mediaId,
  required String movieNumber,
  required int startThumbnailId,
  required int endThumbnailId,
  required int startSeconds,
  required int endSeconds,
}) {
  return showAppDialog<MediaClipDto>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CreateClipDialog(
      mediaId: mediaId,
      movieNumber: movieNumber,
      startThumbnailId: startThumbnailId,
      endThumbnailId: endThumbnailId,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    ),
  );
}

class CreateClipDialog extends ConsumerStatefulWidget {
  const CreateClipDialog({
    super.key,
    required this.mediaId,
    required this.movieNumber,
    required this.startThumbnailId,
    required this.endThumbnailId,
    required this.startSeconds,
    required this.endSeconds,
  });

  final int mediaId;
  final String movieNumber;
  final int startThumbnailId;
  final int endThumbnailId;
  final int startSeconds;
  final int endSeconds;

  @override
  ConsumerState<CreateClipDialog> createState() => _CreateClipDialogState();
}

class _CreateClipDialogState extends ConsumerState<CreateClipDialog> {
  late final TextEditingController _titleController;
  bool _defaultTitleInitialized = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultTitleInitialized) {
      return;
    }
    _defaultTitleInitialized = true;
    // 默认标题采用「番号-切片时长」格式，例如 SSNI-888-3分48秒，用户可继续编辑。
    final duration = (widget.endSeconds - widget.startSeconds).abs();
    final number = widget.movieNumber.trim();
    final durationLabel = formatMediaDurationLabel(
      duration,
      l10n: AppLocalizations.of(context),
    );
    final defaultTitle = number.isEmpty
        ? durationLabel
        : '$number-$durationLabel';
    _titleController.text = defaultTitle;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final lo = widget.startSeconds < widget.endSeconds
        ? widget.startSeconds
        : widget.endSeconds;
    final hi = widget.startSeconds < widget.endSeconds
        ? widget.endSeconds
        : widget.startSeconds;
    final duration = hi - lo;

    return AppDesktopDialog(
      width: context.appComponentTokens.playlistDialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.clipCreateTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            l10n.clipCreateRangeLabel(
              formatMediaTimecode(lo),
              formatMediaTimecode(hi),
              formatMediaTimecode(duration),
            ),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('create-clip-title-field'),
            controller: _titleController,
            hintText: l10n.clipCreateTitleHint,
            enabled: !_isSubmitting,
          ),
          SizedBox(height: spacing.sm),
          Text(
            l10n.clipCreateNotice,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.tertiary,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.commonCancel,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('create-clip-submit-button'),
                  label: l10n.clipCreateAction,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
    });
    try {
      final clip = await ref
          .read(clipsApiProvider)
          .createClip(
            mediaId: widget.mediaId,
            startThumbnailId: widget.startThumbnailId,
            endThumbnailId: widget.endThumbnailId,
            title: _titleController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(clip);
    } catch (error) {
      final isTimeout = _isTimeout(error);
      showToast(_clipErrorMessage(error, l10n), tone: AppToastTone.error);
      if (!mounted) {
        return;
      }
      // 切片超时时后端可能仍在生成，关闭对话框让用户稍后在「我的切片」查看；
      // 其余错误保留对话框便于修正后重试。
      if (isTimeout) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

bool _isTimeout(Object error) {
  return error is ApiException &&
      error.transportFailureKind == ApiTransportFailureKind.timeout;
}

String _clipErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ApiException) {
    if (error.transportFailureKind == ApiTransportFailureKind.timeout) {
      return l10n.clipCreateTimeout;
    }
    switch (error.error?.code) {
      case 'media_clip_too_long':
        return l10n.clipCreateRangeTooLong;
      case 'media_clip_invalid_range':
        return l10n.clipCreateInvalidRange;
      case 'media_clip_generation_failed':
        return l10n.clipCreateFailed;
      case 'media_thumbnail_not_found':
        return l10n.clipCreateThumbnailExpired;
    }
  }
  return apiErrorMessage(
    error,
    fallback: l10n.clipCreateFailedFallback,
    l10n: l10n,
  );
}
