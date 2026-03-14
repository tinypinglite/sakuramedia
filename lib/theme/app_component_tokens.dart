import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppComponentTokens extends ThemeExtension<AppComponentTokens> {
  const AppComponentTokens({
    required this.desktopTitleBarHeight,
    required this.desktopMacTrafficLightInsetWidth,
    required this.desktopTitleBarControlGap,
    required this.overviewStatTileMinWidth,
    required this.overviewStatTileMaxWidth,
    required this.overviewStatSkeletonLabelWidth,
    required this.overviewStatSkeletonLabelHeight,
    required this.overviewStatSkeletonValueWidth,
    required this.overviewStatSkeletonValueHeight,
    required this.movieCardTargetWidth,
    required this.movieThumbnailTargetWidth,
    required this.movieCardAspectRatio,
    required this.movieCardCoverVisibleWidthFactor,
    required this.iconSizeXs,
    required this.iconSizeSm,
    required this.iconSizeMd,
    required this.iconSizeLg,
    required this.iconSizeXl,
    required this.iconSize2xl,
    required this.iconSize3xl,
    required this.iconSize4xl,
    required this.movieCardLoaderSize,
    required this.movieCardLoaderStrokeWidth,
    required this.movieCardStatusBadgeSize,
    required this.movieDetailHeroHeight,
    required this.movieDetailThinCoverWidth,
    required this.movieDetailPlotThumbnailWidth,
    required this.movieDetailPlotThumbnailHeight,
    required this.movieDetailActorAvatarSize,
    required this.movieDetailActorCardWidth,
    required this.movieDetailSectionGap,
    required this.movieDetailSectionTitleGap,
    required this.movieDetailPillHorizontalPadding,
    required this.movieDetailPillVerticalPadding,
    required this.movieDetailPillGap,
    required this.movieDetailBottomBarMinHeight,
    required this.movieDetailMediaRowMinHeight,
    required this.movieDetailMoreEntryHeight,
    required this.movieDetailDialogWidth,
    required this.movieDetailDialogMinHeight,
    required this.movieDetailPlotPreviewMaxWidth,
    required this.movieDetailPlotPreviewMaxHeight,
    required this.movieDetailPlotPreviewThumbnailWidth,
    required this.movieDetailPlotPreviewThumbnailHeight,
    required this.playlistBannerHeight,
    required this.playlistDialogWidth,
    required this.moviePlayerThumbnailAspectRatio,
  });

  const AppComponentTokens.defaults()
    : desktopTitleBarHeight = 56,
      desktopMacTrafficLightInsetWidth = 52,
      desktopTitleBarControlGap = 8,
      overviewStatTileMinWidth = 150,
      overviewStatTileMaxWidth = 190,
      overviewStatSkeletonLabelWidth = 64,
      overviewStatSkeletonLabelHeight = 10,
      overviewStatSkeletonValueWidth = 96,
      overviewStatSkeletonValueHeight = 22,
      movieCardTargetWidth = 160,
      movieThumbnailTargetWidth = 128,
      movieCardAspectRatio = 0.7,
      movieCardCoverVisibleWidthFactor = 0.47,
      iconSizeXs = 16,
      iconSizeSm = 18,
      iconSizeMd = 20,
      iconSizeLg = 22,
      iconSizeXl = 24,
      iconSize2xl = 32,
      iconSize3xl = 36,
      iconSize4xl = 44,
      movieCardLoaderSize = 18,
      movieCardLoaderStrokeWidth = 2,
      movieCardStatusBadgeSize = 24,
      movieDetailHeroHeight = 420,
      movieDetailThinCoverWidth = 180,
      movieDetailPlotThumbnailWidth = 132,
      movieDetailPlotThumbnailHeight = 88,
      movieDetailActorAvatarSize = 58,
      movieDetailActorCardWidth = 84,
      movieDetailSectionGap = 4,
      movieDetailSectionTitleGap = 8,
      movieDetailPillHorizontalPadding = 6,
      movieDetailPillVerticalPadding = 3,
      movieDetailPillGap = 6,
      movieDetailBottomBarMinHeight = 36,
      movieDetailMediaRowMinHeight = 88,
      movieDetailMoreEntryHeight = 56,
      movieDetailDialogWidth = 960,
      movieDetailDialogMinHeight = 560,
      movieDetailPlotPreviewMaxWidth = 980,
      movieDetailPlotPreviewMaxHeight = 720,
      movieDetailPlotPreviewThumbnailWidth = 112,
      movieDetailPlotPreviewThumbnailHeight = 72,
      playlistBannerHeight = 125,
      playlistDialogWidth = 520,
      moviePlayerThumbnailAspectRatio = 16 / 9;

  final double desktopTitleBarHeight;
  final double desktopMacTrafficLightInsetWidth;
  final double desktopTitleBarControlGap;
  final double overviewStatTileMinWidth;
  final double overviewStatTileMaxWidth;
  final double overviewStatSkeletonLabelWidth;
  final double overviewStatSkeletonLabelHeight;
  final double overviewStatSkeletonValueWidth;
  final double overviewStatSkeletonValueHeight;
  final double movieCardTargetWidth;
  final double movieThumbnailTargetWidth;
  final double movieCardAspectRatio;
  final double movieCardCoverVisibleWidthFactor;
  final double iconSizeXs;
  final double iconSizeSm;
  final double iconSizeMd;
  final double iconSizeLg;
  final double iconSizeXl;
  final double iconSize2xl;
  final double iconSize3xl;
  final double iconSize4xl;
  final double movieCardLoaderSize;
  final double movieCardLoaderStrokeWidth;
  final double movieCardStatusBadgeSize;
  final double movieDetailHeroHeight;
  final double movieDetailThinCoverWidth;
  final double movieDetailPlotThumbnailWidth;
  final double movieDetailPlotThumbnailHeight;
  final double movieDetailActorAvatarSize;
  final double movieDetailActorCardWidth;
  final double movieDetailSectionGap;
  final double movieDetailSectionTitleGap;
  final double movieDetailPillHorizontalPadding;
  final double movieDetailPillVerticalPadding;
  final double movieDetailPillGap;
  final double movieDetailBottomBarMinHeight;
  final double movieDetailMediaRowMinHeight;
  final double movieDetailMoreEntryHeight;
  final double movieDetailDialogWidth;
  final double movieDetailDialogMinHeight;
  final double movieDetailPlotPreviewMaxWidth;
  final double movieDetailPlotPreviewMaxHeight;
  final double movieDetailPlotPreviewThumbnailWidth;
  final double movieDetailPlotPreviewThumbnailHeight;
  final double playlistBannerHeight;
  final double playlistDialogWidth;
  final double moviePlayerThumbnailAspectRatio;

  @override
  AppComponentTokens copyWith({
    double? desktopTitleBarHeight,
    double? desktopMacTrafficLightInsetWidth,
    double? desktopTitleBarControlGap,
    double? overviewStatTileMinWidth,
    double? overviewStatTileMaxWidth,
    double? overviewStatSkeletonLabelWidth,
    double? overviewStatSkeletonLabelHeight,
    double? overviewStatSkeletonValueWidth,
    double? overviewStatSkeletonValueHeight,
    double? movieCardTargetWidth,
    double? movieThumbnailTargetWidth,
    double? movieCardAspectRatio,
    double? movieCardCoverVisibleWidthFactor,
    double? iconSizeXs,
    double? iconSizeSm,
    double? iconSizeMd,
    double? iconSizeLg,
    double? iconSizeXl,
    double? iconSize2xl,
    double? iconSize3xl,
    double? iconSize4xl,
    double? movieCardLoaderSize,
    double? movieCardLoaderStrokeWidth,
    double? movieCardStatusBadgeSize,
    double? movieDetailHeroHeight,
    double? movieDetailThinCoverWidth,
    double? movieDetailPlotThumbnailWidth,
    double? movieDetailPlotThumbnailHeight,
    double? movieDetailActorAvatarSize,
    double? movieDetailActorCardWidth,
    double? movieDetailSectionGap,
    double? movieDetailSectionTitleGap,
    double? movieDetailPillHorizontalPadding,
    double? movieDetailPillVerticalPadding,
    double? movieDetailPillGap,
    double? movieDetailBottomBarMinHeight,
    double? movieDetailMediaRowMinHeight,
    double? movieDetailMoreEntryHeight,
    double? movieDetailDialogWidth,
    double? movieDetailDialogMinHeight,
    double? movieDetailPlotPreviewMaxWidth,
    double? movieDetailPlotPreviewMaxHeight,
    double? movieDetailPlotPreviewThumbnailWidth,
    double? movieDetailPlotPreviewThumbnailHeight,
    double? playlistBannerHeight,
    double? playlistDialogWidth,
    double? moviePlayerThumbnailAspectRatio,
  }) {
    return AppComponentTokens(
      desktopTitleBarHeight:
          desktopTitleBarHeight ?? this.desktopTitleBarHeight,
      desktopMacTrafficLightInsetWidth:
          desktopMacTrafficLightInsetWidth ??
          this.desktopMacTrafficLightInsetWidth,
      desktopTitleBarControlGap:
          desktopTitleBarControlGap ?? this.desktopTitleBarControlGap,
      overviewStatTileMinWidth:
          overviewStatTileMinWidth ?? this.overviewStatTileMinWidth,
      overviewStatTileMaxWidth:
          overviewStatTileMaxWidth ?? this.overviewStatTileMaxWidth,
      overviewStatSkeletonLabelWidth:
          overviewStatSkeletonLabelWidth ?? this.overviewStatSkeletonLabelWidth,
      overviewStatSkeletonLabelHeight:
          overviewStatSkeletonLabelHeight ??
          this.overviewStatSkeletonLabelHeight,
      overviewStatSkeletonValueWidth:
          overviewStatSkeletonValueWidth ?? this.overviewStatSkeletonValueWidth,
      overviewStatSkeletonValueHeight:
          overviewStatSkeletonValueHeight ??
          this.overviewStatSkeletonValueHeight,
      movieCardTargetWidth: movieCardTargetWidth ?? this.movieCardTargetWidth,
      movieThumbnailTargetWidth:
          movieThumbnailTargetWidth ?? this.movieThumbnailTargetWidth,
      movieCardAspectRatio: movieCardAspectRatio ?? this.movieCardAspectRatio,
      movieCardCoverVisibleWidthFactor:
          movieCardCoverVisibleWidthFactor ??
          this.movieCardCoverVisibleWidthFactor,
      iconSizeXs: iconSizeXs ?? this.iconSizeXs,
      iconSizeSm: iconSizeSm ?? this.iconSizeSm,
      iconSizeMd: iconSizeMd ?? this.iconSizeMd,
      iconSizeLg: iconSizeLg ?? this.iconSizeLg,
      iconSizeXl: iconSizeXl ?? this.iconSizeXl,
      iconSize2xl: iconSize2xl ?? this.iconSize2xl,
      iconSize3xl: iconSize3xl ?? this.iconSize3xl,
      iconSize4xl: iconSize4xl ?? this.iconSize4xl,
      movieCardLoaderSize: movieCardLoaderSize ?? this.movieCardLoaderSize,
      movieCardLoaderStrokeWidth:
          movieCardLoaderStrokeWidth ?? this.movieCardLoaderStrokeWidth,
      movieCardStatusBadgeSize:
          movieCardStatusBadgeSize ?? this.movieCardStatusBadgeSize,
      movieDetailHeroHeight:
          movieDetailHeroHeight ?? this.movieDetailHeroHeight,
      movieDetailThinCoverWidth:
          movieDetailThinCoverWidth ?? this.movieDetailThinCoverWidth,
      movieDetailPlotThumbnailWidth:
          movieDetailPlotThumbnailWidth ?? this.movieDetailPlotThumbnailWidth,
      movieDetailPlotThumbnailHeight:
          movieDetailPlotThumbnailHeight ?? this.movieDetailPlotThumbnailHeight,
      movieDetailActorAvatarSize:
          movieDetailActorAvatarSize ?? this.movieDetailActorAvatarSize,
      movieDetailActorCardWidth:
          movieDetailActorCardWidth ?? this.movieDetailActorCardWidth,
      movieDetailSectionGap:
          movieDetailSectionGap ?? this.movieDetailSectionGap,
      movieDetailSectionTitleGap:
          movieDetailSectionTitleGap ?? this.movieDetailSectionTitleGap,
      movieDetailPillHorizontalPadding:
          movieDetailPillHorizontalPadding ??
          this.movieDetailPillHorizontalPadding,
      movieDetailPillVerticalPadding:
          movieDetailPillVerticalPadding ?? this.movieDetailPillVerticalPadding,
      movieDetailPillGap: movieDetailPillGap ?? this.movieDetailPillGap,
      movieDetailBottomBarMinHeight:
          movieDetailBottomBarMinHeight ?? this.movieDetailBottomBarMinHeight,
      movieDetailMediaRowMinHeight:
          movieDetailMediaRowMinHeight ?? this.movieDetailMediaRowMinHeight,
      movieDetailMoreEntryHeight:
          movieDetailMoreEntryHeight ?? this.movieDetailMoreEntryHeight,
      movieDetailDialogWidth:
          movieDetailDialogWidth ?? this.movieDetailDialogWidth,
      movieDetailDialogMinHeight:
          movieDetailDialogMinHeight ?? this.movieDetailDialogMinHeight,
      movieDetailPlotPreviewMaxWidth:
          movieDetailPlotPreviewMaxWidth ?? this.movieDetailPlotPreviewMaxWidth,
      movieDetailPlotPreviewMaxHeight:
          movieDetailPlotPreviewMaxHeight ??
          this.movieDetailPlotPreviewMaxHeight,
      movieDetailPlotPreviewThumbnailWidth:
          movieDetailPlotPreviewThumbnailWidth ??
          this.movieDetailPlotPreviewThumbnailWidth,
      movieDetailPlotPreviewThumbnailHeight:
          movieDetailPlotPreviewThumbnailHeight ??
          this.movieDetailPlotPreviewThumbnailHeight,
      playlistBannerHeight: playlistBannerHeight ?? this.playlistBannerHeight,
      playlistDialogWidth: playlistDialogWidth ?? this.playlistDialogWidth,
      moviePlayerThumbnailAspectRatio:
          moviePlayerThumbnailAspectRatio ??
          this.moviePlayerThumbnailAspectRatio,
    );
  }

  @override
  AppComponentTokens lerp(ThemeExtension<AppComponentTokens>? other, double t) {
    if (other is! AppComponentTokens) {
      return this;
    }
    return AppComponentTokens(
      desktopTitleBarHeight:
          lerpDouble(desktopTitleBarHeight, other.desktopTitleBarHeight, t)!,
      desktopMacTrafficLightInsetWidth:
          lerpDouble(
            desktopMacTrafficLightInsetWidth,
            other.desktopMacTrafficLightInsetWidth,
            t,
          )!,
      desktopTitleBarControlGap:
          lerpDouble(
            desktopTitleBarControlGap,
            other.desktopTitleBarControlGap,
            t,
          )!,
      overviewStatTileMinWidth:
          lerpDouble(
            overviewStatTileMinWidth,
            other.overviewStatTileMinWidth,
            t,
          )!,
      overviewStatTileMaxWidth:
          lerpDouble(
            overviewStatTileMaxWidth,
            other.overviewStatTileMaxWidth,
            t,
          )!,
      overviewStatSkeletonLabelWidth:
          lerpDouble(
            overviewStatSkeletonLabelWidth,
            other.overviewStatSkeletonLabelWidth,
            t,
          )!,
      overviewStatSkeletonLabelHeight:
          lerpDouble(
            overviewStatSkeletonLabelHeight,
            other.overviewStatSkeletonLabelHeight,
            t,
          )!,
      overviewStatSkeletonValueWidth:
          lerpDouble(
            overviewStatSkeletonValueWidth,
            other.overviewStatSkeletonValueWidth,
            t,
          )!,
      overviewStatSkeletonValueHeight:
          lerpDouble(
            overviewStatSkeletonValueHeight,
            other.overviewStatSkeletonValueHeight,
            t,
          )!,
      movieCardTargetWidth:
          lerpDouble(movieCardTargetWidth, other.movieCardTargetWidth, t)!,
      movieThumbnailTargetWidth:
          lerpDouble(
            movieThumbnailTargetWidth,
            other.movieThumbnailTargetWidth,
            t,
          )!,
      movieCardAspectRatio:
          lerpDouble(movieCardAspectRatio, other.movieCardAspectRatio, t)!,
      movieCardCoverVisibleWidthFactor:
          lerpDouble(
            movieCardCoverVisibleWidthFactor,
            other.movieCardCoverVisibleWidthFactor,
            t,
          )!,
      iconSizeXs: lerpDouble(iconSizeXs, other.iconSizeXs, t)!,
      iconSizeSm: lerpDouble(iconSizeSm, other.iconSizeSm, t)!,
      iconSizeMd: lerpDouble(iconSizeMd, other.iconSizeMd, t)!,
      iconSizeLg: lerpDouble(iconSizeLg, other.iconSizeLg, t)!,
      iconSizeXl: lerpDouble(iconSizeXl, other.iconSizeXl, t)!,
      iconSize2xl: lerpDouble(iconSize2xl, other.iconSize2xl, t)!,
      iconSize3xl: lerpDouble(iconSize3xl, other.iconSize3xl, t)!,
      iconSize4xl: lerpDouble(iconSize4xl, other.iconSize4xl, t)!,
      movieCardLoaderSize:
          lerpDouble(movieCardLoaderSize, other.movieCardLoaderSize, t)!,
      movieCardLoaderStrokeWidth:
          lerpDouble(
            movieCardLoaderStrokeWidth,
            other.movieCardLoaderStrokeWidth,
            t,
          )!,
      movieCardStatusBadgeSize:
          lerpDouble(
            movieCardStatusBadgeSize,
            other.movieCardStatusBadgeSize,
            t,
          )!,
      movieDetailHeroHeight:
          lerpDouble(movieDetailHeroHeight, other.movieDetailHeroHeight, t)!,
      movieDetailThinCoverWidth:
          lerpDouble(
            movieDetailThinCoverWidth,
            other.movieDetailThinCoverWidth,
            t,
          )!,
      movieDetailPlotThumbnailWidth:
          lerpDouble(
            movieDetailPlotThumbnailWidth,
            other.movieDetailPlotThumbnailWidth,
            t,
          )!,
      movieDetailPlotThumbnailHeight:
          lerpDouble(
            movieDetailPlotThumbnailHeight,
            other.movieDetailPlotThumbnailHeight,
            t,
          )!,
      movieDetailActorAvatarSize:
          lerpDouble(
            movieDetailActorAvatarSize,
            other.movieDetailActorAvatarSize,
            t,
          )!,
      movieDetailActorCardWidth:
          lerpDouble(
            movieDetailActorCardWidth,
            other.movieDetailActorCardWidth,
            t,
          )!,
      movieDetailSectionGap:
          lerpDouble(movieDetailSectionGap, other.movieDetailSectionGap, t)!,
      movieDetailSectionTitleGap:
          lerpDouble(
            movieDetailSectionTitleGap,
            other.movieDetailSectionTitleGap,
            t,
          )!,
      movieDetailPillHorizontalPadding:
          lerpDouble(
            movieDetailPillHorizontalPadding,
            other.movieDetailPillHorizontalPadding,
            t,
          )!,
      movieDetailPillVerticalPadding:
          lerpDouble(
            movieDetailPillVerticalPadding,
            other.movieDetailPillVerticalPadding,
            t,
          )!,
      movieDetailPillGap:
          lerpDouble(movieDetailPillGap, other.movieDetailPillGap, t)!,
      movieDetailBottomBarMinHeight:
          lerpDouble(
            movieDetailBottomBarMinHeight,
            other.movieDetailBottomBarMinHeight,
            t,
          )!,
      movieDetailMediaRowMinHeight:
          lerpDouble(
            movieDetailMediaRowMinHeight,
            other.movieDetailMediaRowMinHeight,
            t,
          )!,
      movieDetailMoreEntryHeight:
          lerpDouble(
            movieDetailMoreEntryHeight,
            other.movieDetailMoreEntryHeight,
            t,
          )!,
      movieDetailDialogWidth:
          lerpDouble(movieDetailDialogWidth, other.movieDetailDialogWidth, t)!,
      movieDetailDialogMinHeight:
          lerpDouble(
            movieDetailDialogMinHeight,
            other.movieDetailDialogMinHeight,
            t,
          )!,
      movieDetailPlotPreviewMaxWidth:
          lerpDouble(
            movieDetailPlotPreviewMaxWidth,
            other.movieDetailPlotPreviewMaxWidth,
            t,
          )!,
      movieDetailPlotPreviewMaxHeight:
          lerpDouble(
            movieDetailPlotPreviewMaxHeight,
            other.movieDetailPlotPreviewMaxHeight,
            t,
          )!,
      movieDetailPlotPreviewThumbnailWidth:
          lerpDouble(
            movieDetailPlotPreviewThumbnailWidth,
            other.movieDetailPlotPreviewThumbnailWidth,
            t,
          )!,
      movieDetailPlotPreviewThumbnailHeight:
          lerpDouble(
            movieDetailPlotPreviewThumbnailHeight,
            other.movieDetailPlotPreviewThumbnailHeight,
            t,
          )!,
      playlistBannerHeight:
          lerpDouble(playlistBannerHeight, other.playlistBannerHeight, t)!,
      playlistDialogWidth:
          lerpDouble(playlistDialogWidth, other.playlistDialogWidth, t)!,
      moviePlayerThumbnailAspectRatio:
          lerpDouble(
            moviePlayerThumbnailAspectRatio,
            other.moviePlayerThumbnailAspectRatio,
            t,
          )!,
    );
  }
}

extension AppComponentTokensThemeDataX on ThemeData {
  AppComponentTokens get appComponentTokens =>
      extension<AppComponentTokens>() ?? const AppComponentTokens.defaults();
}

extension AppComponentTokensBuildContextX on BuildContext {
  AppComponentTokens get appComponentTokens =>
      Theme.of(this).appComponentTokens;
}
