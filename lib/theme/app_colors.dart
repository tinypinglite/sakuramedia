import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfacePage,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.desktopSidebarGlassTint,
    required this.desktopSidebarGlassHover,
    required this.desktopSidebarGlassActive,
    required this.sidebarBackground,
    required this.sidebarHoverBackground,
    required this.sidebarActiveBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnMedia,
    required this.subscriptionHeartIcon,
    required this.borderSubtle,
    required this.borderStrong,
    required this.divider,
    required this.mediaOverlaySoft,
    required this.mediaOverlayStrong,
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
    required this.movieDetailWantWatchCountIcon,
  });

  const AppColors.defaults()
    : surfacePage = const Color(0xFFF5F5F5),
      surfaceCard = const Color(0xFFFFFFFF),
      surfaceElevated = const Color(0xFFFFFFFF),
      surfaceMuted = const Color(0xFFF1F1F1),
      desktopSidebarGlassTint = const Color(0x4CEFEFEF),
      desktopSidebarGlassHover = const Color(0x80FFFFFF),
      desktopSidebarGlassActive = const Color(0x99FFFFFF),
      sidebarBackground = const Color(0xFFD7D9D9),
      sidebarHoverBackground = const Color(0xFFC3C5C5),
      sidebarActiveBackground = const Color(0xFFC3C5C5),
      textPrimary = const Color(0xFF1F1A18),
      textSecondary = const Color.fromARGB(255, 21, 21, 21),
      textMuted = const Color(0xFF7A7A7A),
      textOnMedia = const Color(0xFFFFFFFF),
      subscriptionHeartIcon = const Color(0xFFD44B5C),
      borderSubtle = const Color(0xFFE5E5E5),
      borderStrong = const Color(0xFFD6D6D6),
      divider = const Color(0xFFE8E8E8),
      mediaOverlaySoft = const Color(0x14000000),
      mediaOverlayStrong = const Color(0x85000000),
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
      movieDetailWantWatchCountIcon = const Color(0xFFC65A74);

  final Color surfacePage;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color desktopSidebarGlassTint;
  final Color desktopSidebarGlassHover;
  final Color desktopSidebarGlassActive;
  final Color sidebarBackground;
  final Color sidebarHoverBackground;
  final Color sidebarActiveBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnMedia;
  final Color subscriptionHeartIcon;
  final Color borderSubtle;
  final Color borderStrong;
  final Color divider;
  final Color mediaOverlaySoft;
  final Color mediaOverlayStrong;
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
  final Color movieDetailWantWatchCountIcon;

  @override
  AppColors copyWith({
    Color? surfacePage,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? desktopSidebarGlassTint,
    Color? desktopSidebarGlassHover,
    Color? desktopSidebarGlassActive,
    Color? sidebarBackground,
    Color? sidebarHoverBackground,
    Color? sidebarActiveBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnMedia,
    Color? subscriptionHeartIcon,
    Color? borderSubtle,
    Color? borderStrong,
    Color? divider,
    Color? mediaOverlaySoft,
    Color? mediaOverlayStrong,
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
    Color? movieDetailWantWatchCountIcon,
  }) {
    return AppColors(
      surfacePage: surfacePage ?? this.surfacePage,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      desktopSidebarGlassTint:
          desktopSidebarGlassTint ?? this.desktopSidebarGlassTint,
      desktopSidebarGlassHover:
          desktopSidebarGlassHover ?? this.desktopSidebarGlassHover,
      desktopSidebarGlassActive:
          desktopSidebarGlassActive ?? this.desktopSidebarGlassActive,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarHoverBackground:
          sidebarHoverBackground ?? this.sidebarHoverBackground,
      sidebarActiveBackground:
          sidebarActiveBackground ?? this.sidebarActiveBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnMedia: textOnMedia ?? this.textOnMedia,
      subscriptionHeartIcon:
          subscriptionHeartIcon ?? this.subscriptionHeartIcon,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      mediaOverlaySoft: mediaOverlaySoft ?? this.mediaOverlaySoft,
      mediaOverlayStrong: mediaOverlayStrong ?? this.mediaOverlayStrong,
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
      desktopSidebarGlassTint:
          Color.lerp(
            desktopSidebarGlassTint,
            other.desktopSidebarGlassTint,
            t,
          )!,
      desktopSidebarGlassHover:
          Color.lerp(
            desktopSidebarGlassHover,
            other.desktopSidebarGlassHover,
            t,
          )!,
      desktopSidebarGlassActive:
          Color.lerp(
            desktopSidebarGlassActive,
            other.desktopSidebarGlassActive,
            t,
          )!,
      sidebarBackground:
          Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      sidebarHoverBackground:
          Color.lerp(sidebarHoverBackground, other.sidebarHoverBackground, t)!,
      sidebarActiveBackground:
          Color.lerp(
            sidebarActiveBackground,
            other.sidebarActiveBackground,
            t,
          )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnMedia: Color.lerp(textOnMedia, other.textOnMedia, t)!,
      subscriptionHeartIcon:
          Color.lerp(subscriptionHeartIcon, other.subscriptionHeartIcon, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      mediaOverlaySoft:
          Color.lerp(mediaOverlaySoft, other.mediaOverlaySoft, t)!,
      mediaOverlayStrong:
          Color.lerp(mediaOverlayStrong, other.mediaOverlayStrong, t)!,
      mediaMaskOverlay:
          Color.lerp(mediaMaskOverlay, other.mediaMaskOverlay, t)!,
      movieCardSubscribedBadgeBackground:
          Color.lerp(
            movieCardSubscribedBadgeBackground,
            other.movieCardSubscribedBadgeBackground,
            t,
          )!,
      movieCardPlayableBadgeBackground:
          Color.lerp(
            movieCardPlayableBadgeBackground,
            other.movieCardPlayableBadgeBackground,
            t,
          )!,
      movieDetailPlayableBadgeBackground:
          Color.lerp(
            movieDetailPlayableBadgeBackground,
            other.movieDetailPlayableBadgeBackground,
            t,
          )!,
      movieDetailSelectedPlotBorder:
          Color.lerp(
            movieDetailSelectedPlotBorder,
            other.movieDetailSelectedPlotBorder,
            t,
          )!,
      movieDetailEmptyBackground:
          Color.lerp(
            movieDetailEmptyBackground,
            other.movieDetailEmptyBackground,
            t,
          )!,
      movieDetailInvalidMediaBackground:
          Color.lerp(
            movieDetailInvalidMediaBackground,
            other.movieDetailInvalidMediaBackground,
            t,
          )!,
      movieDetailInvalidMediaForeground:
          Color.lerp(
            movieDetailInvalidMediaForeground,
            other.movieDetailInvalidMediaForeground,
            t,
          )!,
      movieDetailHeroBackgroundStart:
          Color.lerp(
            movieDetailHeroBackgroundStart,
            other.movieDetailHeroBackgroundStart,
            t,
          )!,
      movieDetailHeroBackgroundEnd:
          Color.lerp(
            movieDetailHeroBackgroundEnd,
            other.movieDetailHeroBackgroundEnd,
            t,
          )!,
      movieDetailReleaseDateIcon:
          Color.lerp(
            movieDetailReleaseDateIcon,
            other.movieDetailReleaseDateIcon,
            t,
          )!,
      movieDetailDurationIcon:
          Color.lerp(
            movieDetailDurationIcon,
            other.movieDetailDurationIcon,
            t,
          )!,
      movieDetailScoreIcon:
          Color.lerp(movieDetailScoreIcon, other.movieDetailScoreIcon, t)!,
      movieDetailScoreCountIcon:
          Color.lerp(
            movieDetailScoreCountIcon,
            other.movieDetailScoreCountIcon,
            t,
          )!,
      movieDetailCommentCountIcon:
          Color.lerp(
            movieDetailCommentCountIcon,
            other.movieDetailCommentCountIcon,
            t,
          )!,
      movieDetailWantWatchCountIcon:
          Color.lerp(
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

extension AppColorsBuildContextX on BuildContext {
  AppColors get appColors => Theme.of(this).appColors;
}
