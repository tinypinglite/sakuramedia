import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

const Duration defaultPlaybackResumePromptTimeout = Duration(seconds: 8);

/// 播放开始后悬浮在控制栏上方的非阻塞续播提示。
///
/// 用户不操作时继续从头播放；超时只负责回调，由父级移除本组件并解除进度上报冻结。
class PlaybackResumePrompt extends StatefulWidget {
  const PlaybackResumePrompt({
    super.key,
    required this.position,
    required this.onResume,
    required this.onStartOver,
    this.autoDismissAfter = defaultPlaybackResumePromptTimeout,
  });

  final Duration position;
  final VoidCallback onResume;
  final VoidCallback onStartOver;
  final Duration autoDismissAfter;

  @override
  State<PlaybackResumePrompt> createState() => _PlaybackResumePromptState();
}

class _PlaybackResumePromptState extends State<PlaybackResumePrompt> {
  Timer? _dismissTimer;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _armDismissTimer();
  }

  @override
  void didUpdateWidget(covariant PlaybackResumePrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.autoDismissAfter != widget.autoDismissAfter) {
      _resolved = false;
      _armDismissTimer();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _armDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(
      widget.autoDismissAfter,
      () => _resolve(widget.onStartOver),
    );
  }

  void _resolve(VoidCallback callback) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _dismissTimer?.cancel();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    return Semantics(
      container: true,
      label: l10n.baseResumePromptSemantic,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.appLayoutTokens.dialogWidthSm,
        ),
        child: AppSurface(
          key: const Key('playback-resume-prompt'),
          borderRadius: context.appRadius.lgBorder,
          role: AppSurfaceRole.overlay,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: componentTokens.buttonHeightSm,
                height: componentTokens.buttonHeightSm,
                decoration: BoxDecoration(
                  color: context.appColors.surfaceMuted,
                  borderRadius: context.appRadius.mdBorder,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.history_rounded,
                  size: componentTokens.iconSizeSm,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: spacing.md),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l10n.baseResumeLastWatched} '),
                      TextSpan(
                        text: formatMediaTimecode(widget.position.inSeconds),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.accent,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              AppButton(
                label: l10n.baseResumeContinue,
                labelKey: const Key('playback-resume-continue-label'),
                size: AppButtonSize.xSmall,
                variant: AppButtonVariant.primary,
                onPressed: () => _resolve(widget.onResume),
              ),
              SizedBox(width: spacing.xs),
              AppTextButton(
                label: l10n.baseResumeStartOver,
                labelKey: const Key('playback-resume-start-over-label'),
                size: AppTextButtonSize.xSmall,
                onPressed: () => _resolve(widget.onStartOver),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 将续播提示放到播放器控制栏上方，桌面与触摸端统一靠左。
class PlaybackResumePromptOverlay extends StatelessWidget {
  const PlaybackResumePromptOverlay({
    super.key,
    required this.position,
    required this.onResume,
    required this.onStartOver,
  });

  final Duration position;
  final VoidCallback onResume;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            overlayTokens.playerControlBarHorizontalInset,
            0,
            overlayTokens.playerControlBarHorizontalInset,
            overlayTokens.playerSeekBarBottomInset + context.appSpacing.xl,
          ),
          child: PlaybackResumePrompt(
            position: position,
            onResume: onResume,
            onStartOver: onStartOver,
          ),
        ),
      ),
    );
  }
}
