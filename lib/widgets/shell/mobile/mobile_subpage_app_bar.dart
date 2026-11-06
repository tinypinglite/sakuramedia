import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 移动子页导航栏：标准、玻璃、沉浸和随滚动收起四种形态。
class AppMobileSubpageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppMobileSubpageAppBar({
    super.key,
    required this.title,
    required this.titleOverride,
    required this.onBack,
    this.immersive = false,
    this.glassChrome = false,
    this.autoHide = false,
    this.hidden = false,
    this.animationDuration = const Duration(milliseconds: 180),
  });

  final String title;
  final ValueListenable<String?> titleOverride;
  final VoidCallback onBack;

  /// 沉浸详情：透明底 + 返回栏悬浮在内容之上（影片详情用）。
  final bool immersive;

  /// 透明页面背景 + 液态玻璃返回按钮的子页导航栏。
  final bool glassChrome;

  /// 子页是否随滚动收起 AppBar。
  final bool autoHide;

  /// [autoHide] 为 true 时，当前是否已滚离顶部。
  final bool hidden;
  final Duration animationDuration;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final useGlassChrome = glassChrome && !immersive;
    final useAutoHide = autoHide && !useGlassChrome;
    final appBar = _buildAppBar(context, useGlassChrome: useGlassChrome);
    if (!useAutoHide) {
      return appBar;
    }
    if (immersive) {
      return _AutoHideOverlayAppBar(
        hidden: hidden,
        duration: animationDuration,
        child: appBar,
      );
    }
    return AnimatedSize(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: hidden
          ? const SizedBox(width: double.infinity)
          : SizedBox(height: kToolbarHeight, child: appBar),
    );
  }

  AppBar _buildAppBar(BuildContext context, {required bool useGlassChrome}) {
    final l10n = appL10n(context);
    return AppBar(
      key: const Key('mobile-subpage-topbar'),
      backgroundColor: immersive || useGlassChrome
          ? Colors.transparent
          : context.appColors.surfaceCard,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: immersive
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.appColors.mediaOverlayStrong.withValues(
                      alpha: 0.55,
                    ),
                    context.appColors.mediaOverlayStrong.withValues(alpha: 0),
                  ],
                ),
              ),
            )
          : null,
      leadingWidth: useGlassChrome
          ? 60
          : context.appComponentTokens.mobileSubpageLeadingWidth,
      titleSpacing: 0, // 默认 16
      leading: useGlassChrome
          ? Padding(
              padding: EdgeInsets.only(left: context.appSpacing.sm),
              child: Center(
                child: AppGlassIconButton(
                  key: const Key('mobile-subpage-back-button'),
                  tooltip: l10n.shellBack,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: onBack,
                ),
              ),
            )
          : IconButton(
              iconSize: context.appComponentTokens.iconSizeSm,
              key: const Key('mobile-subpage-back-button'),
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                // 沉浸页压在封面和顶部压暗渐变上，沿用媒体前景色保证可读。
                color: immersive ? context.appTextPalette.onMedia : null,
              ),
              tooltip: l10n.shellBack,
            ),
      title: immersive
          // 沉浸页不占标题位：封面直通状态栏，顶栏只留返回键和渐变。
          ? null
          : ValueListenableBuilder<String?>(
              valueListenable: titleOverride,
              builder: (context, override, _) {
                final resolved =
                    (override != null && override.trim().isNotEmpty)
                    ? override
                    : title;
                return Text(
                  resolved,
                  key: const Key('mobile-subpage-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: useGlassChrome ? AppTextSize.s16 : AppTextSize.s14,
                    weight: useGlassChrome
                        ? AppTextWeight.semibold
                        : AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                );
              },
            ),
    );
  }
}

/// 沉浸子页的悬浮返回栏：滚离顶部时淡出，正文保持全幅铺底不位移。
///
/// 与普通子页不同，这里不能用高度动画——沉浸页的 AppBar 是叠在内容上的，
/// 高度归零不会让内容上移，反而会闪一次布局。淡出期间仍保留 preferredSize，
/// 隐藏后屏蔽命中和语义，避免透明返回键被点到或读屏读到。
class _AutoHideOverlayAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AutoHideOverlayAppBar({
    required this.hidden,
    required this.duration,
    required this.child,
  });

  final bool hidden;
  final Duration duration;

  /// 必须是 [AppBar]：它自身携带状态栏高度和工具栏高度。
  final AppBar child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}
