import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class PreviewImageStage extends StatelessWidget {
  const PreviewImageStage({
    super.key,
    this.stageKey,
    this.imageKey,
    this.closeButtonKey,
    required this.imageUrl,
    required this.height,
    required this.onClose,
    this.backgroundColor,
    this.fit = BoxFit.contain,
    this.showCloseButton = true,
    this.overlayChild,
    this.enablePinchToFullscreen = false,
    this.fullscreenImageKey,
  });

  final Key? stageKey;
  final Key? imageKey;
  final Key? closeButtonKey;
  final String imageUrl;
  final double height;
  final VoidCallback onClose;
  final Color? backgroundColor;
  final BoxFit fit;
  final bool showCloseButton;
  final Widget? overlayChild;
  final bool enablePinchToFullscreen;
  final Key? fullscreenImageKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return SizedBox(
      key: stageKey,
      width: double.infinity,
      height: height,
      child: ColoredBox(
        color: backgroundColor ?? Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AppPinchToFullscreenImage(
                  enabled: enablePinchToFullscreen,
                  url: imageUrl,
                  fit: fit,
                  fullscreenImageKey: fullscreenImageKey,
                  child: MaskedImage(key: imageKey, url: imageUrl, fit: fit),
                ),
              ),
            ),
            if (overlayChild != null) overlayChild!,
            if (showCloseButton)
              Positioned(
                top: spacing.sm,
                right: spacing.sm,
                child: AppIconButton(
                  key: closeButtonKey,
                  tooltip: '关闭',
                  onPressed: onClose,
                  backgroundColor: Colors.black.withValues(alpha: 0.28),
                  iconColor: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
