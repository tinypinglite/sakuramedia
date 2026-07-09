import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

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
  return showDialog<MediaClipDto>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => CreateClipDialog(
          mediaId: mediaId,
          movieNumber: movieNumber,
          startThumbnailId: startThumbnailId,
          endThumbnailId: endThumbnailId,
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        ),
  );
}

class CreateClipDialog extends StatefulWidget {
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
  State<CreateClipDialog> createState() => _CreateClipDialogState();
}

class _CreateClipDialogState extends State<CreateClipDialog> {
  late final TextEditingController _titleController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 默认标题采用「番号-切片时长」格式，例如 SSNI-888-3分48秒，用户可继续编辑。
    final duration = (widget.endSeconds - widget.startSeconds).abs();
    final number = widget.movieNumber.trim();
    final durationLabel = formatMediaDurationLabel(duration);
    final defaultTitle =
        number.isEmpty ? durationLabel : '$number-$durationLabel';
    _titleController = TextEditingController(text: defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final lo =
        widget.startSeconds < widget.endSeconds
            ? widget.startSeconds
            : widget.endSeconds;
    final hi =
        widget.startSeconds < widget.endSeconds
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
            '新建切片',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            '${formatMediaTimecode(lo)} – ${formatMediaTimecode(hi)} · '
            '时长 ${formatMediaTimecode(duration)}',
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
            hintText: '切片标题（可选）',
            enabled: !_isSubmitting,
          ),
          SizedBox(height: spacing.sm),
          Text(
            '切片由服务器同步生成，较长区间可能需要等待。',
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
                  label: '取消',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('create-clip-submit-button'),
                  label: '创建',
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
    setState(() {
      _isSubmitting = true;
    });
    try {
      final clip = await context.read<ClipsApi>().createClip(
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
      showToast(_clipErrorMessage(error));
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

String _clipErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.transportFailureKind == ApiTransportFailureKind.timeout) {
      return '切片耗时较长，请稍后在「我的切片」查看';
    }
    switch (error.error?.code) {
      case 'media_clip_too_long':
        return '区间过长（最长 15 分钟）';
      case 'media_clip_invalid_range':
        return '请选择不同的起止点';
      case 'media_clip_generation_failed':
        return '切片失败，请重试';
      case 'media_thumbnail_not_found':
        return '缩略图已失效，请重新选择';
    }
  }
  return apiErrorMessage(error, fallback: '创建切片失败，请重试');
}
