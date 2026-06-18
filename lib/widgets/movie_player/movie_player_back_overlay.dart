import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerBackButton extends StatelessWidget {
  const MoviePlayerBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final overlayTokens = context.appOverlayTokens;

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: InkWell(
        key: const Key('movie-player-back-button'),
        borderRadius: context.appRadius.pillBorder,
        onTap: onPressed,
        child: SizedBox(
          width: overlayTokens.playerBackBadgeMinHeight,
          height: overlayTokens.playerBackBadgeMinHeight,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: componentTokens.iconSizeSm,
            color: context.appTextPalette.onMedia,
          ),
        ),
      ),
    );
  }
}

class MoviePlayerInfoButton extends StatelessWidget {
  const MoviePlayerInfoButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final overlayTokens = context.appOverlayTokens;
    return Tooltip(
      message: '播放信息',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: context.appRadius.pillBorder,
        child: InkWell(
          key: const Key('movie-player-info-button'),
          borderRadius: context.appRadius.pillBorder,
          onTap: onPressed,
          child: SizedBox(
            width: overlayTokens.playerBackBadgeMinHeight,
            height: overlayTokens.playerBackBadgeMinHeight,
            child: Icon(
              Icons.info_outline_rounded,
              size: componentTokens.iconSizeSm,
              color: context.appTextPalette.onMedia,
            ),
          ),
        ),
      ),
    );
  }
}

class MoviePlayerCurrentNumberBadge extends StatelessWidget {
  const MoviePlayerCurrentNumberBadge({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final resolvedMovieNumber = movieNumber.trim();

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: Container(
        key: const Key('movie-player-current-number'),
        constraints: BoxConstraints(
          minHeight: overlayTokens.playerBackBadgeMinHeight,
          maxWidth: overlayTokens.playerBackBadgeMaxWidth,
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: overlayTokens.controlTrailingGap,
        ),
        child: Text(
          resolvedMovieNumber,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.onMedia,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}

class MoviePlayerBackWithNumberControl extends StatelessWidget {
  const MoviePlayerBackWithNumberControl({
    super.key,
    required this.onPressed,
    required this.movieNumber,
  });

  final VoidCallback onPressed;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoviePlayerBackButton(onPressed: onPressed),
        SizedBox(width: context.appSpacing.xs / 2),
        MoviePlayerCurrentNumberBadge(movieNumber: movieNumber),
      ],
    );
  }
}

class MoviePlayerBackOverlay extends StatelessWidget {
  const MoviePlayerBackOverlay({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    // Align(topLeft) 兜底：本组件可能被放进 `StackFit.expand` 的 Stack（如
    // MoviePlayerSurfaceFrame 的 readiness 蒙版层）而拿到「强制撑满」的 tight 约束。
    // 若不收口，tight 约束会穿透到 SizedBox/Icon，把返回箭头 glyph 居中到屏幕正中。
    // Align 在被撑满时给子节点宽松约束并左上对齐，保证按钮恒按自身大小贴左上角。
    return Align(
      alignment: Alignment.topLeft,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: overlayTokens.playerBackOverlayLeft,
            top: overlayTokens.playerBackOverlayTop,
          ),
          child: MoviePlayerBackButton(onPressed: onPressed),
        ),
      ),
    );
  }
}

/// 把「播放器未就绪」UI（加载转圈 / 错误态 / 黑屏）包进 [Stack]，左上角叠一个
/// 独立于 media_kit 的返回按钮。
///
/// 各播放页的返回按钮平时长在 media_kit `Video` 的控制层里，只有播放器组件渲染
/// 出来后才存在；播放器还没就绪（拉流/解析地址/初始化）时若卡住，界面上就没有任何
/// 返回入口。这些阶段统一用本函数兜底，确保任何时候都能退出。
///
/// 实际可点的按钮始终带 `Key('movie-player-back-button')`（在 [MoviePlayerBackButton]
/// 内部），测试可据此点击；[backButtonKey] 仅用于给外层覆盖层一个稳定锚点。
Widget wrapWithMoviePlayerBackButton({
  required Widget child,
  required VoidCallback onBackPressed,
  Key? backButtonKey,
}) {
  return Stack(
    children: [
      Positioned.fill(child: child),
      MoviePlayerBackOverlay(key: backButtonKey, onPressed: onBackPressed),
    ],
  );
}
