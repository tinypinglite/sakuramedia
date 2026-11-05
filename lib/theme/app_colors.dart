import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme/app_theme_color.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfacePage,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.noticeSurface,
    required this.desktopSidebarGlassTint,
    required this.windowsSidebarGlassTint,
    required this.desktopSidebarGlassHover,
    required this.desktopSidebarGlassActive,
    required this.sidebarBackground,
    required this.sidebarHoverBackground,
    required this.sidebarActiveBackground,
    required this.subscriptionHeartIcon,
    required this.borderSubtle,
    required this.borderStrong,
    required this.divider,
    required this.selectionSurface,
    required this.selectionBorder,
    required this.infoSurface,
    required this.warningSurface,
    required this.errorSurface,
    required this.errorAccentForeground,
    required this.successSurface,
    required this.mediaOverlaySoft,
    required this.mediaOverlayStrong,
    required this.mediaOverlayBorder,
    required this.mediaMaskOverlay,
    required this.movieCardSubscribedBadgeBackground,
    required this.movieCardPlayableBadgeBackground,
    required this.movieDetailPlayableBadgeBackground,
    required this.movieDetailSelectedPlotBorder,
    required this.movieDetailEmptyBackground,
    required this.movieDetailInvalidMediaBackground,
    required this.movieDetailInvalidMediaForeground,
    required this.movieDetailHeroBackgroundStart,
    required this.movieDetailHeroBackgroundEnd,
    required this.movieDetailReleaseDateIcon,
    required this.movieDetailDurationIcon,
    required this.movieDetailScoreIcon,
    required this.movieDetailScoreCountIcon,
    required this.movieDetailCommentCountIcon,
    required this.movieDetailHeatIcon,
    required this.movieDetailWantWatchCountIcon,
  });

  const AppColors.defaults()
    : surfacePage = const Color(0xFFF5F5F5),
      surfaceCard = const Color(0xFFFFFFFF),
      surfaceElevated = const Color(0xFFFFFFFF),
      surfaceMuted = const Color(0xFFF1F1F1),
      noticeSurface = const Color(0xFFF3F3F3),
      desktopSidebarGlassTint = const Color(0x33F7F3F0),
      windowsSidebarGlassTint = const Color(0xEBEFEFEF),
      desktopSidebarGlassHover = const Color(0x80FFFFFF),
      desktopSidebarGlassActive = const Color(0x99FFFFFF),
      sidebarBackground = const Color(0xFFD7D9D9),
      sidebarHoverBackground = const Color(0xFFC3C5C5),
      sidebarActiveBackground = const Color(0xFFC3C5C5),
      subscriptionHeartIcon = const Color(0xFFD44B5C),
      borderSubtle = const Color(0xFFE5E5E5),
      borderStrong = const Color(0xFFD6D6D6),
      divider = const Color(0xFFE8E8E8),
      selectionSurface = const Color(0xFFF7ECEB),
      selectionBorder = const Color(0xFF6B2D2A),
      infoSurface = const Color(0xFFEFF6FF),
      warningSurface = const Color(0xFFFFF4E5),
      errorSurface = const Color(0xFFFFF1EF),
      errorAccentForeground = const Color(0xFFF04438),
      successSurface = const Color(0xFFECFDF3),
      mediaOverlaySoft = const Color(0x14000000),
      mediaOverlayStrong = const Color(0x85000000),
      mediaOverlayBorder = const Color(0x6BE5E5E5),
      mediaMaskOverlay = const Color(0xE6000000),
      movieCardSubscribedBadgeBackground = const Color(0xFFF97316),
      movieCardPlayableBadgeBackground = const Color(0xFF1677FF),
      movieDetailPlayableBadgeBackground = const Color(0xFF1677FF),
      movieDetailSelectedPlotBorder = const Color(0xFF6B2D2A),
      movieDetailEmptyBackground = const Color(0xFFF0ECEA),
      movieDetailInvalidMediaBackground = const Color(0xFFF8E8E6),
      movieDetailInvalidMediaForeground = const Color(0xFF9C3D35),
      movieDetailHeroBackgroundStart = const Color(0xFF000000),
      movieDetailHeroBackgroundEnd = const Color(0xFF000000),
      movieDetailReleaseDateIcon = const Color(0xFF2F7D6B),
      movieDetailDurationIcon = const Color(0xFFB26A1F),
      movieDetailScoreIcon = const Color(0xFFD29B18),
      movieDetailScoreCountIcon = const Color(0xFF3A6FB0),
      movieDetailCommentCountIcon = const Color(0xFF7A55B0),
      movieDetailHeatIcon = const Color(0xFFD84C57),
      movieDetailWantWatchCountIcon = const Color(0xFFC65A74);

  /// 深色中性规格；品牌槽位先用酒红暗色占位，由 [of] 按主题色覆盖。
  const AppColors._darkNeutral()
    : surfacePage = const Color(0xFF121212),
      surfaceCard = const Color(0xFF1E1E1E),
      surfaceElevated = const Color(0xFF262626),
      surfaceMuted = const Color(0xFF2A2A2A),
      noticeSurface = const Color(0xFF232323),
      desktopSidebarGlassTint = const Color(0x4D181315),
      windowsSidebarGlassTint = const Color(0xEB1E1E1E),
      desktopSidebarGlassHover = const Color(0x14FFFFFF),
      desktopSidebarGlassActive = const Color(0x1FFFFFFF),
      sidebarBackground = const Color(0xFF1A1A1A),
      sidebarHoverBackground = const Color(0x14FFFFFF),
      sidebarActiveBackground = const Color(0x1FFFFFFF),
      subscriptionHeartIcon = const Color(0xFFE06A75),
      borderSubtle = const Color(0x1FFFFFFF),
      borderStrong = const Color(0x2EFFFFFF),
      divider = const Color(0x14FFFFFF),
      selectionSurface = const Color(0xFF3A2422),
      selectionBorder = const Color(0xFFE9A29B),
      infoSurface = const Color(0xFF14263D),
      warningSurface = const Color(0xFF3A2A15),
      errorSurface = const Color(0xFF3A1D1B),
      errorAccentForeground = const Color(0xFFFF6B5E),
      successSurface = const Color(0xFF122E1F),
      mediaOverlaySoft = const Color(0x14000000),
      mediaOverlayStrong = const Color(0x85000000),
      mediaOverlayBorder = const Color(0x6BFFFFFF),
      mediaMaskOverlay = const Color(0xE6000000),
      movieCardSubscribedBadgeBackground = const Color(0xFFF97316),
      movieCardPlayableBadgeBackground = const Color(0xFF1677FF),
      movieDetailPlayableBadgeBackground = const Color(0xFF1677FF),
      movieDetailSelectedPlotBorder = const Color(0xFFE9A29B),
      movieDetailEmptyBackground = const Color(0xFF2A2725),
      movieDetailInvalidMediaBackground = const Color(0xFF3A2320),
      movieDetailInvalidMediaForeground = const Color(0xFFF0A79E),
      movieDetailHeroBackgroundStart = const Color(0xFF000000),
      movieDetailHeroBackgroundEnd = const Color(0xFF000000),
      movieDetailReleaseDateIcon = const Color(0xFF58A895),
      movieDetailDurationIcon = const Color(0xFFD19045),
      movieDetailScoreIcon = const Color(0xFFE2B34A),
      movieDetailScoreCountIcon = const Color(0xFF6E9FD8),
      movieDetailCommentCountIcon = const Color(0xFFA98BD9),
      movieDetailHeatIcon = const Color(0xFFE87881),
      movieDetailWantWatchCountIcon = const Color(0xFFDC8298);

  static AppColors of({
    required AppThemeColor themeColor,
    required Brightness brightness,
  }) {
    final brand = themeColor.forBrightness(brightness);
    final base = brightness == Brightness.dark
        ? const AppColors._darkNeutral()
        : const AppColors.defaults();
    return base.copyWith(
      selectionSurface: brand.selectionSurface,
      selectionBorder: brand.selectionBorder,
      movieDetailSelectedPlotBorder: brand.selectedPlotBorder,
    );
  }

  final Color surfacePage;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color noticeSurface;
  final Color desktopSidebarGlassTint;

  /// Windows 的系统模糊比 macOS vibrancy 更透明，tint 需要更实，
  /// 避免背景窗口内容干扰导航文字。
  final Color windowsSidebarGlassTint;
  final Color desktopSidebarGlassHover;
  final Color desktopSidebarGlassActive;
  final Color sidebarBackground;
  final Color sidebarHoverBackground;
  final Color sidebarActiveBackground;
  final Color subscriptionHeartIcon;
  final Color borderSubtle;
  final Color borderStrong;
  final Color divider;
  final Color selectionSurface;
  final Color selectionBorder;
  final Color infoSurface;
  final Color warningSurface;
  final Color errorSurface;
  final Color errorAccentForeground;
  final Color successSurface;
  final Color mediaOverlaySoft;
  final Color mediaOverlayStrong;

  /// 媒体图上的胶囊/圆形角标描边：亮色用灰白、暗色用半透明白，保证在深色叠加层上可见。
  final Color mediaOverlayBorder;
  final Color mediaMaskOverlay;
  final Color movieCardSubscribedBadgeBackground;
  final Color movieCardPlayableBadgeBackground;
  final Color movieDetailPlayableBadgeBackground;
  final Color movieDetailSelectedPlotBorder;
  final Color movieDetailEmptyBackground;
  final Color movieDetailInvalidMediaBackground;
  final Color movieDetailInvalidMediaForeground;
  final Color movieDetailHeroBackgroundStart;
  final Color movieDetailHeroBackgroundEnd;
  final Color movieDetailReleaseDateIcon;
  final Color movieDetailDurationIcon;
  final Color movieDetailScoreIcon;
  final Color movieDetailScoreCountIcon;
  final Color movieDetailCommentCountIcon;
  final Color movieDetailHeatIcon;
  final Color movieDetailWantWatchCountIcon;

  @override
  AppColors copyWith({
    Color? surfacePage,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? noticeSurface,
    Color? desktopSidebarGlassTint,
    Color? windowsSidebarGlassTint,
    Color? desktopSidebarGlassHover,
    Color? desktopSidebarGlassActive,
    Color? sidebarBackground,
    Color? sidebarHoverBackground,
    Color? sidebarActiveBackground,
    Color? subscriptionHeartIcon,
    Color? borderSubtle,
    Color? borderStrong,
    Color? divider,
    Color? selectionSurface,
    Color? selectionBorder,
    Color? infoSurface,
    Color? warningSurface,
    Color? errorSurface,
    Color? errorAccentForeground,
    Color? successSurface,
    Color? mediaOverlaySoft,
    Color? mediaOverlayStrong,
    Color? mediaOverlayBorder,
    Color? mediaMaskOverlay,
    Color? movieCardSubscribedBadgeBackground,
    Color? movieCardPlayableBadgeBackground,
    Color? movieDetailPlayableBadgeBackground,
    Color? movieDetailSelectedPlotBorder,
    Color? movieDetailEmptyBackground,
    Color? movieDetailInvalidMediaBackground,
    Color? movieDetailInvalidMediaForeground,
    Color? movieDetailHeroBackgroundStart,
    Color? movieDetailHeroBackgroundEnd,
    Color? movieDetailReleaseDateIcon,
    Color? movieDetailDurationIcon,
    Color? movieDetailScoreIcon,
    Color? movieDetailScoreCountIcon,
    Color? movieDetailCommentCountIcon,
    Color? movieDetailHeatIcon,
    Color? movieDetailWantWatchCountIcon,
  }) {
    return AppColors(
      surfacePage: surfacePage ?? this.surfacePage,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      noticeSurface: noticeSurface ?? this.noticeSurface,
      desktopSidebarGlassTint:
          desktopSidebarGlassTint ?? this.desktopSidebarGlassTint,
      windowsSidebarGlassTint:
          windowsSidebarGlassTint ?? this.windowsSidebarGlassTint,
      desktopSidebarGlassHover:
          desktopSidebarGlassHover ?? this.desktopSidebarGlassHover,
      desktopSidebarGlassActive:
          desktopSidebarGlassActive ?? this.desktopSidebarGlassActive,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarHoverBackground:
          sidebarHoverBackground ?? this.sidebarHoverBackground,
      sidebarActiveBackground:
          sidebarActiveBackground ?? this.sidebarActiveBackground,
      subscriptionHeartIcon:
          subscriptionHeartIcon ?? this.subscriptionHeartIcon,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      selectionSurface: selectionSurface ?? this.selectionSurface,
      selectionBorder: selectionBorder ?? this.selectionBorder,
      infoSurface: infoSurface ?? this.infoSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      errorSurface: errorSurface ?? this.errorSurface,
      errorAccentForeground:
          errorAccentForeground ?? this.errorAccentForeground,
      successSurface: successSurface ?? this.successSurface,
      mediaOverlaySoft: mediaOverlaySoft ?? this.mediaOverlaySoft,
      mediaOverlayStrong: mediaOverlayStrong ?? this.mediaOverlayStrong,
      mediaOverlayBorder: mediaOverlayBorder ?? this.mediaOverlayBorder,
      mediaMaskOverlay: mediaMaskOverlay ?? this.mediaMaskOverlay,
      movieCardSubscribedBadgeBackground:
          movieCardSubscribedBadgeBackground ??
          this.movieCardSubscribedBadgeBackground,
      movieCardPlayableBadgeBackground:
          movieCardPlayableBadgeBackground ??
          this.movieCardPlayableBadgeBackground,
      movieDetailPlayableBadgeBackground:
          movieDetailPlayableBadgeBackground ??
          this.movieDetailPlayableBadgeBackground,
      movieDetailSelectedPlotBorder:
          movieDetailSelectedPlotBorder ?? this.movieDetailSelectedPlotBorder,
      movieDetailEmptyBackground:
          movieDetailEmptyBackground ?? this.movieDetailEmptyBackground,
      movieDetailInvalidMediaBackground:
          movieDetailInvalidMediaBackground ??
          this.movieDetailInvalidMediaBackground,
      movieDetailInvalidMediaForeground:
          movieDetailInvalidMediaForeground ??
          this.movieDetailInvalidMediaForeground,
      movieDetailHeroBackgroundStart:
          movieDetailHeroBackgroundStart ?? this.movieDetailHeroBackgroundStart,
      movieDetailHeroBackgroundEnd:
          movieDetailHeroBackgroundEnd ?? this.movieDetailHeroBackgroundEnd,
      movieDetailReleaseDateIcon:
          movieDetailReleaseDateIcon ?? this.movieDetailReleaseDateIcon,
      movieDetailDurationIcon:
          movieDetailDurationIcon ?? this.movieDetailDurationIcon,
      movieDetailScoreIcon: movieDetailScoreIcon ?? this.movieDetailScoreIcon,
      movieDetailScoreCountIcon:
          movieDetailScoreCountIcon ?? this.movieDetailScoreCountIcon,
      movieDetailCommentCountIcon:
          movieDetailCommentCountIcon ?? this.movieDetailCommentCountIcon,
      movieDetailHeatIcon: movieDetailHeatIcon ?? this.movieDetailHeatIcon,
      movieDetailWantWatchCountIcon:
          movieDetailWantWatchCountIcon ?? this.movieDetailWantWatchCountIcon,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      surfacePage: Color.lerp(surfacePage, other.surfacePage, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      noticeSurface: Color.lerp(noticeSurface, other.noticeSurface, t)!,
      desktopSidebarGlassTint: Color.lerp(
        desktopSidebarGlassTint,
        other.desktopSidebarGlassTint,
        t,
      )!,
      windowsSidebarGlassTint: Color.lerp(
        windowsSidebarGlassTint,
        other.windowsSidebarGlassTint,
        t,
      )!,
      desktopSidebarGlassHover: Color.lerp(
        desktopSidebarGlassHover,
        other.desktopSidebarGlassHover,
        t,
      )!,
      desktopSidebarGlassActive: Color.lerp(
        desktopSidebarGlassActive,
        other.desktopSidebarGlassActive,
        t,
      )!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      sidebarHoverBackground: Color.lerp(
        sidebarHoverBackground,
        other.sidebarHoverBackground,
        t,
      )!,
      sidebarActiveBackground: Color.lerp(
        sidebarActiveBackground,
        other.sidebarActiveBackground,
        t,
      )!,
      subscriptionHeartIcon: Color.lerp(
        subscriptionHeartIcon,
        other.subscriptionHeartIcon,
        t,
      )!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      selectionSurface: Color.lerp(
        selectionSurface,
        other.selectionSurface,
        t,
      )!,
      selectionBorder: Color.lerp(selectionBorder, other.selectionBorder, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      errorAccentForeground: Color.lerp(
        errorAccentForeground,
        other.errorAccentForeground,
        t,
      )!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      mediaOverlaySoft: Color.lerp(
        mediaOverlaySoft,
        other.mediaOverlaySoft,
        t,
      )!,
      mediaOverlayStrong: Color.lerp(
        mediaOverlayStrong,
        other.mediaOverlayStrong,
        t,
      )!,
      mediaOverlayBorder: Color.lerp(
        mediaOverlayBorder,
        other.mediaOverlayBorder,
        t,
      )!,
      mediaMaskOverlay: Color.lerp(
        mediaMaskOverlay,
        other.mediaMaskOverlay,
        t,
      )!,
      movieCardSubscribedBadgeBackground: Color.lerp(
        movieCardSubscribedBadgeBackground,
        other.movieCardSubscribedBadgeBackground,
        t,
      )!,
      movieCardPlayableBadgeBackground: Color.lerp(
        movieCardPlayableBadgeBackground,
        other.movieCardPlayableBadgeBackground,
        t,
      )!,
      movieDetailPlayableBadgeBackground: Color.lerp(
        movieDetailPlayableBadgeBackground,
        other.movieDetailPlayableBadgeBackground,
        t,
      )!,
      movieDetailSelectedPlotBorder: Color.lerp(
        movieDetailSelectedPlotBorder,
        other.movieDetailSelectedPlotBorder,
        t,
      )!,
      movieDetailEmptyBackground: Color.lerp(
        movieDetailEmptyBackground,
        other.movieDetailEmptyBackground,
        t,
      )!,
      movieDetailInvalidMediaBackground: Color.lerp(
        movieDetailInvalidMediaBackground,
        other.movieDetailInvalidMediaBackground,
        t,
      )!,
      movieDetailInvalidMediaForeground: Color.lerp(
        movieDetailInvalidMediaForeground,
        other.movieDetailInvalidMediaForeground,
        t,
      )!,
      movieDetailHeroBackgroundStart: Color.lerp(
        movieDetailHeroBackgroundStart,
        other.movieDetailHeroBackgroundStart,
        t,
      )!,
      movieDetailHeroBackgroundEnd: Color.lerp(
        movieDetailHeroBackgroundEnd,
        other.movieDetailHeroBackgroundEnd,
        t,
      )!,
      movieDetailReleaseDateIcon: Color.lerp(
        movieDetailReleaseDateIcon,
        other.movieDetailReleaseDateIcon,
        t,
      )!,
      movieDetailDurationIcon: Color.lerp(
        movieDetailDurationIcon,
        other.movieDetailDurationIcon,
        t,
      )!,
      movieDetailScoreIcon: Color.lerp(
        movieDetailScoreIcon,
        other.movieDetailScoreIcon,
        t,
      )!,
      movieDetailScoreCountIcon: Color.lerp(
        movieDetailScoreCountIcon,
        other.movieDetailScoreCountIcon,
        t,
      )!,
      movieDetailCommentCountIcon: Color.lerp(
        movieDetailCommentCountIcon,
        other.movieDetailCommentCountIcon,
        t,
      )!,
      movieDetailHeatIcon: Color.lerp(
        movieDetailHeatIcon,
        other.movieDetailHeatIcon,
        t,
      )!,
      movieDetailWantWatchCountIcon: Color.lerp(
        movieDetailWantWatchCountIcon,
        other.movieDetailWantWatchCountIcon,
        t,
      )!,
    );
  }
}

extension AppColorsThemeDataX on ThemeData {
  AppColors get appColors =>
      extension<AppColors>() ?? const AppColors.defaults();
}

/// 在当前 alpha 基础上按 [factor] 再淡化，得到「更弱」的颜色。
///
/// 对 alpha 为 1 的实色 token 等价于 `withValues(alpha: factor)`；
/// 对深色下本身就是半透明白的描边/分隔 token（[AppColors.borderSubtle] 等），
/// 使用 `withValues(alpha: factor)` 会把透明度「替换」成 factor 而反向变亮，
/// 这里改为相乘，保证深浅色下都是「更弱」的语义。
extension AppColorFadeX on Color {
  Color fadedBy(double factor) => withValues(alpha: a * factor);
}

extension AppColorsBuildContextX on BuildContext {
  AppColors get appColors => Theme.of(this).appColors;
}
