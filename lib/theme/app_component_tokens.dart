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
    required this.iconSize2xs,
    required this.iconSize3xs,
    required this.iconSizeSm,
    required this.iconSizeMd,
    required this.iconSizeLg,
    required this.iconSizeXl,
    required this.iconSize2xl,
    required this.iconSize3xl,
    required this.iconSize4xl,
    required this.buttonHeightMd,
    required this.buttonHeightSm,
    required this.buttonHeightXs,
    required this.buttonHeight2xs,
    required this.buttonHeight3xs,
    required this.buttonHorizontalPaddingMd,
    required this.buttonHorizontalPaddingSm,
    required this.buttonHorizontalPaddingXs,
    required this.buttonHorizontalPadding2xs,
    required this.buttonHorizontalPadding3xs,
    required this.buttonGapMd,
    required this.buttonGapSm,
    required this.buttonGapXs,
    required this.buttonGap2xs,
    required this.buttonGap3xs,
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
    required this.mobileBottomNavHeight,
    required this.mobileTopTabHeight,
    required this.mobileSubpageLeadingWidth,
    required this.mobileLatestMovieCardWidth,
    required this.mobileFollowMovieCardHeight,
    required this.mobileFollowMovieThinCoverWidth,
    required this.mobileFollowMovieStillWidth,
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
        iconSize2xs = 14,
        iconSize3xs = 12,
        iconSizeSm = 18,
        iconSizeMd = 20,
        iconSizeLg = 22,
        iconSizeXl = 24,
        iconSize2xl = 32,
        iconSize3xl = 36,
        iconSize4xl = 44,
        buttonHeightMd = 36,
        buttonHeightSm = 32,
        buttonHeightXs = 28,
        buttonHeight2xs = 24,
        buttonHeight3xs = 20,
        buttonHorizontalPaddingMd = 14,
        buttonHorizontalPaddingSm = 10,
        buttonHorizontalPaddingXs = 8,
        buttonHorizontalPadding2xs = 6,
        buttonHorizontalPadding3xs = 4,
        buttonGapMd = 8,
        buttonGapSm = 6,
        buttonGapXs = 4,
        buttonGap2xs = 4,
        buttonGap3xs = 2,
        movieCardLoaderSize = 18,
        movieCardLoaderStrokeWidth = 2,
        movieCardStatusBadgeSize = 24,
        movieDetailHeroHeight = 420,
        movieDetailThinCoverWidth = 180,
        movieDetailPlotThumbnailWidth = 132,
        movieDetailPlotThumbnailHeight = 88,
        movieDetailActorAvatarSize = 58,
        movieDetailActorCardWidth = 84,
        movieDetailSectionGap = 16,
        movieDetailSectionTitleGap = 8,
        movieDetailPillHorizontalPadding = 5,
        movieDetailPillVerticalPadding = 2,
        movieDetailPillGap = 6,
        movieDetailBottomBarMinHeight = 42,
        movieDetailMediaRowMinHeight = 88,
        movieDetailMoreEntryHeight = 56,
        movieDetailDialogWidth = 960,
        movieDetailDialogMinHeight = 560,
        movieDetailPlotPreviewMaxWidth = 980,
        movieDetailPlotPreviewMaxHeight = 720,
        movieDetailPlotPreviewThumbnailWidth = 112,
        movieDetailPlotPreviewThumbnailHeight = 72,
        playlistBannerHeight = 100,
        playlistDialogWidth = 520,
        mobileBottomNavHeight = 52,
        mobileTopTabHeight = 48,
        mobileSubpageLeadingWidth = 40,
        mobileLatestMovieCardWidth = 142,
        mobileFollowMovieCardHeight = 150,
        mobileFollowMovieThinCoverWidth = 96,
        mobileFollowMovieStillWidth = 86,
        moviePlayerThumbnailAspectRatio = 16 / 9;

  const AppComponentTokens.mobile()
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
        iconSize2xs = 14,
        iconSize3xs = 12,
        iconSizeSm = 18,
        iconSizeMd = 20,
        iconSizeLg = 22,
        iconSizeXl = 24,
        iconSize2xl = 32,
        iconSize3xl = 36,
        iconSize4xl = 44,
        buttonHeightMd = 40,
        buttonHeightSm = 36,
        buttonHeightXs = 32,
        buttonHeight2xs = 28,
        buttonHeight3xs = 24,
        buttonHorizontalPaddingMd = 16,
        buttonHorizontalPaddingSm = 12,
        buttonHorizontalPaddingXs = 10,
        buttonHorizontalPadding2xs = 8,
        buttonHorizontalPadding3xs = 6,
        buttonGapMd = 8,
        buttonGapSm = 6,
        buttonGapXs = 4,
        buttonGap2xs = 4,
        buttonGap3xs = 2,
        movieCardLoaderSize = 18,
        movieCardLoaderStrokeWidth = 2,
        movieCardStatusBadgeSize = 24,
        movieDetailHeroHeight = 420,
        movieDetailThinCoverWidth = 180,
        movieDetailPlotThumbnailWidth = 132,
        movieDetailPlotThumbnailHeight = 88,
        movieDetailActorAvatarSize = 58,
        movieDetailActorCardWidth = 84,
        movieDetailSectionGap = 16,
        movieDetailSectionTitleGap = 8,
        movieDetailPillHorizontalPadding = 6,
        movieDetailPillVerticalPadding = 3,
        movieDetailPillGap = 6,
        movieDetailBottomBarMinHeight = 48,
        movieDetailMediaRowMinHeight = 92,
        movieDetailMoreEntryHeight = 60,
        movieDetailDialogWidth = 960,
        movieDetailDialogMinHeight = 560,
        movieDetailPlotPreviewMaxWidth = 980,
        movieDetailPlotPreviewMaxHeight = 720,
        movieDetailPlotPreviewThumbnailWidth = 112,
        movieDetailPlotPreviewThumbnailHeight = 72,
        playlistBannerHeight = 104,
        playlistDialogWidth = 520,
        mobileBottomNavHeight = 56,
        mobileTopTabHeight = 52,
        mobileSubpageLeadingWidth = 44,
        mobileLatestMovieCardWidth = 148,
        mobileFollowMovieCardHeight = 158,
        mobileFollowMovieThinCoverWidth = 100,
        mobileFollowMovieStillWidth = 90,
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
  final double iconSize2xs;
  final double iconSize3xs;
  final double iconSizeSm;
  final double iconSizeMd;
  final double iconSizeLg;
  final double iconSizeXl;
  final double iconSize2xl;
  final double iconSize3xl;
  final double iconSize4xl;
  final double buttonHeightMd;
  final double buttonHeightSm;
  final double buttonHeightXs;
  final double buttonHeight2xs;
  final double buttonHeight3xs;
  final double buttonHorizontalPaddingMd;
  final double buttonHorizontalPaddingSm;
  final double buttonHorizontalPaddingXs;
  final double buttonHorizontalPadding2xs;
  final double buttonHorizontalPadding3xs;
  final double buttonGapMd;
  final double buttonGapSm;
  final double buttonGapXs;
  final double buttonGap2xs;
  final double buttonGap3xs;
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
  final double mobileBottomNavHeight;
  final double mobileTopTabHeight;
  final double mobileSubpageLeadingWidth;
  final double mobileLatestMovieCardWidth;
  final double mobileFollowMovieCardHeight;
  final double mobileFollowMovieThinCoverWidth;
  final double mobileFollowMovieStillWidth;
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
    double? iconSize2xs,
    double? iconSize3xs,
    double? iconSizeSm,
    double? iconSizeMd,
    double? iconSizeLg,
    double? iconSizeXl,
    double? iconSize2xl,
    double? iconSize3xl,
    double? iconSize4xl,
    double? buttonHeightMd,
    double? buttonHeightSm,
    double? buttonHeightXs,
    double? buttonHeight2xs,
    double? buttonHeight3xs,
    double? buttonHorizontalPaddingMd,
    double? buttonHorizontalPaddingSm,
    double? buttonHorizontalPaddingXs,
    double? buttonHorizontalPadding2xs,
    double? buttonHorizontalPadding3xs,
    double? buttonGapMd,
    double? buttonGapSm,
    double? buttonGapXs,
    double? buttonGap2xs,
    double? buttonGap3xs,
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
    double? mobileBottomNavHeight,
    double? mobileTopTabHeight,
    double? mobileSubpageLeadingWidth,
    double? mobileLatestMovieCardWidth,
    double? mobileFollowMovieCardHeight,
    double? mobileFollowMovieThinCoverWidth,
    double? mobileFollowMovieStillWidth,
    double? moviePlayerThumbnailAspectRatio,
  }) {
    return AppComponentTokens(
      desktopTitleBarHeight:
          desktopTitleBarHeight ?? this.desktopTitleBarHeight,
      desktopMacTrafficLightInsetWidth: desktopMacTrafficLightInsetWidth ??
          this.desktopMacTrafficLightInsetWidth,
      desktopTitleBarControlGap:
          desktopTitleBarControlGap ?? this.desktopTitleBarControlGap,
      overviewStatTileMinWidth:
          overviewStatTileMinWidth ?? this.overviewStatTileMinWidth,
      overviewStatTileMaxWidth:
          overviewStatTileMaxWidth ?? this.overviewStatTileMaxWidth,
      overviewStatSkeletonLabelWidth:
          overviewStatSkeletonLabelWidth ?? this.overviewStatSkeletonLabelWidth,
      overviewStatSkeletonLabelHeight: overviewStatSkeletonLabelHeight ??
          this.overviewStatSkeletonLabelHeight,
      overviewStatSkeletonValueWidth:
          overviewStatSkeletonValueWidth ?? this.overviewStatSkeletonValueWidth,
      overviewStatSkeletonValueHeight: overviewStatSkeletonValueHeight ??
          this.overviewStatSkeletonValueHeight,
      movieCardTargetWidth: movieCardTargetWidth ?? this.movieCardTargetWidth,
      movieThumbnailTargetWidth:
          movieThumbnailTargetWidth ?? this.movieThumbnailTargetWidth,
      movieCardAspectRatio: movieCardAspectRatio ?? this.movieCardAspectRatio,
      movieCardCoverVisibleWidthFactor: movieCardCoverVisibleWidthFactor ??
          this.movieCardCoverVisibleWidthFactor,
      iconSizeXs: iconSizeXs ?? this.iconSizeXs,
      iconSize2xs: iconSize2xs ?? this.iconSize2xs,
      iconSize3xs: iconSize3xs ?? this.iconSize3xs,
      iconSizeSm: iconSizeSm ?? this.iconSizeSm,
      iconSizeMd: iconSizeMd ?? this.iconSizeMd,
      iconSizeLg: iconSizeLg ?? this.iconSizeLg,
      iconSizeXl: iconSizeXl ?? this.iconSizeXl,
      iconSize2xl: iconSize2xl ?? this.iconSize2xl,
      iconSize3xl: iconSize3xl ?? this.iconSize3xl,
      iconSize4xl: iconSize4xl ?? this.iconSize4xl,
      buttonHeightMd: buttonHeightMd ?? this.buttonHeightMd,
      buttonHeightSm: buttonHeightSm ?? this.buttonHeightSm,
      buttonHeightXs: buttonHeightXs ?? this.buttonHeightXs,
      buttonHeight2xs: buttonHeight2xs ?? this.buttonHeight2xs,
      buttonHeight3xs: buttonHeight3xs ?? this.buttonHeight3xs,
      buttonHorizontalPaddingMd:
          buttonHorizontalPaddingMd ?? this.buttonHorizontalPaddingMd,
      buttonHorizontalPaddingSm:
          buttonHorizontalPaddingSm ?? this.buttonHorizontalPaddingSm,
      buttonHorizontalPaddingXs:
          buttonHorizontalPaddingXs ?? this.buttonHorizontalPaddingXs,
      buttonHorizontalPadding2xs:
          buttonHorizontalPadding2xs ?? this.buttonHorizontalPadding2xs,
      buttonHorizontalPadding3xs:
          buttonHorizontalPadding3xs ?? this.buttonHorizontalPadding3xs,
      buttonGapMd: buttonGapMd ?? this.buttonGapMd,
      buttonGapSm: buttonGapSm ?? this.buttonGapSm,
      buttonGapXs: buttonGapXs ?? this.buttonGapXs,
      buttonGap2xs: buttonGap2xs ?? this.buttonGap2xs,
      buttonGap3xs: buttonGap3xs ?? this.buttonGap3xs,
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
      movieDetailPillHorizontalPadding: movieDetailPillHorizontalPadding ??
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
      movieDetailPlotPreviewMaxHeight: movieDetailPlotPreviewMaxHeight ??
          this.movieDetailPlotPreviewMaxHeight,
      movieDetailPlotPreviewThumbnailWidth:
          movieDetailPlotPreviewThumbnailWidth ??
              this.movieDetailPlotPreviewThumbnailWidth,
      movieDetailPlotPreviewThumbnailHeight:
          movieDetailPlotPreviewThumbnailHeight ??
              this.movieDetailPlotPreviewThumbnailHeight,
      playlistBannerHeight: playlistBannerHeight ?? this.playlistBannerHeight,
      playlistDialogWidth: playlistDialogWidth ?? this.playlistDialogWidth,
      mobileBottomNavHeight:
          mobileBottomNavHeight ?? this.mobileBottomNavHeight,
      mobileTopTabHeight: mobileTopTabHeight ?? this.mobileTopTabHeight,
      mobileSubpageLeadingWidth:
          mobileSubpageLeadingWidth ?? this.mobileSubpageLeadingWidth,
      mobileLatestMovieCardWidth:
          mobileLatestMovieCardWidth ?? this.mobileLatestMovieCardWidth,
      mobileFollowMovieCardHeight:
          mobileFollowMovieCardHeight ?? this.mobileFollowMovieCardHeight,
      mobileFollowMovieThinCoverWidth: mobileFollowMovieThinCoverWidth ??
          this.mobileFollowMovieThinCoverWidth,
      mobileFollowMovieStillWidth:
          mobileFollowMovieStillWidth ?? this.mobileFollowMovieStillWidth,
      moviePlayerThumbnailAspectRatio: moviePlayerThumbnailAspectRatio ??
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
      desktopMacTrafficLightInsetWidth: lerpDouble(
        desktopMacTrafficLightInsetWidth,
        other.desktopMacTrafficLightInsetWidth,
        t,
      )!,
      desktopTitleBarControlGap: lerpDouble(
        desktopTitleBarControlGap,
        other.desktopTitleBarControlGap,
        t,
      )!,
      overviewStatTileMinWidth: lerpDouble(
        overviewStatTileMinWidth,
        other.overviewStatTileMinWidth,
        t,
      )!,
      overviewStatTileMaxWidth: lerpDouble(
        overviewStatTileMaxWidth,
        other.overviewStatTileMaxWidth,
        t,
      )!,
      overviewStatSkeletonLabelWidth: lerpDouble(
        overviewStatSkeletonLabelWidth,
        other.overviewStatSkeletonLabelWidth,
        t,
      )!,
      overviewStatSkeletonLabelHeight: lerpDouble(
        overviewStatSkeletonLabelHeight,
        other.overviewStatSkeletonLabelHeight,
        t,
      )!,
      overviewStatSkeletonValueWidth: lerpDouble(
        overviewStatSkeletonValueWidth,
        other.overviewStatSkeletonValueWidth,
        t,
      )!,
      overviewStatSkeletonValueHeight: lerpDouble(
        overviewStatSkeletonValueHeight,
        other.overviewStatSkeletonValueHeight,
        t,
      )!,
      movieCardTargetWidth:
          lerpDouble(movieCardTargetWidth, other.movieCardTargetWidth, t)!,
      movieThumbnailTargetWidth: lerpDouble(
        movieThumbnailTargetWidth,
        other.movieThumbnailTargetWidth,
        t,
      )!,
      movieCardAspectRatio:
          lerpDouble(movieCardAspectRatio, other.movieCardAspectRatio, t)!,
      movieCardCoverVisibleWidthFactor: lerpDouble(
        movieCardCoverVisibleWidthFactor,
        other.movieCardCoverVisibleWidthFactor,
        t,
      )!,
      iconSizeXs: lerpDouble(iconSizeXs, other.iconSizeXs, t)!,
      iconSize2xs: lerpDouble(iconSize2xs, other.iconSize2xs, t)!,
      iconSize3xs: lerpDouble(iconSize3xs, other.iconSize3xs, t)!,
      iconSizeSm: lerpDouble(iconSizeSm, other.iconSizeSm, t)!,
      iconSizeMd: lerpDouble(iconSizeMd, other.iconSizeMd, t)!,
      iconSizeLg: lerpDouble(iconSizeLg, other.iconSizeLg, t)!,
      iconSizeXl: lerpDouble(iconSizeXl, other.iconSizeXl, t)!,
      iconSize2xl: lerpDouble(iconSize2xl, other.iconSize2xl, t)!,
      iconSize3xl: lerpDouble(iconSize3xl, other.iconSize3xl, t)!,
      iconSize4xl: lerpDouble(iconSize4xl, other.iconSize4xl, t)!,
      buttonHeightMd: lerpDouble(buttonHeightMd, other.buttonHeightMd, t)!,
      buttonHeightSm: lerpDouble(buttonHeightSm, other.buttonHeightSm, t)!,
      buttonHeightXs: lerpDouble(buttonHeightXs, other.buttonHeightXs, t)!,
      buttonHeight2xs: lerpDouble(buttonHeight2xs, other.buttonHeight2xs, t)!,
      buttonHeight3xs: lerpDouble(buttonHeight3xs, other.buttonHeight3xs, t)!,
      buttonHorizontalPaddingMd: lerpDouble(
        buttonHorizontalPaddingMd,
        other.buttonHorizontalPaddingMd,
        t,
      )!,
      buttonHorizontalPaddingSm: lerpDouble(
        buttonHorizontalPaddingSm,
        other.buttonHorizontalPaddingSm,
        t,
      )!,
      buttonHorizontalPaddingXs: lerpDouble(
        buttonHorizontalPaddingXs,
        other.buttonHorizontalPaddingXs,
        t,
      )!,
      buttonHorizontalPadding2xs: lerpDouble(
        buttonHorizontalPadding2xs,
        other.buttonHorizontalPadding2xs,
        t,
      )!,
      buttonHorizontalPadding3xs: lerpDouble(
        buttonHorizontalPadding3xs,
        other.buttonHorizontalPadding3xs,
        t,
      )!,
      buttonGapMd: lerpDouble(buttonGapMd, other.buttonGapMd, t)!,
      buttonGapSm: lerpDouble(buttonGapSm, other.buttonGapSm, t)!,
      buttonGapXs: lerpDouble(buttonGapXs, other.buttonGapXs, t)!,
      buttonGap2xs: lerpDouble(buttonGap2xs, other.buttonGap2xs, t)!,
      buttonGap3xs: lerpDouble(buttonGap3xs, other.buttonGap3xs, t)!,
      movieCardLoaderSize:
          lerpDouble(movieCardLoaderSize, other.movieCardLoaderSize, t)!,
      movieCardLoaderStrokeWidth: lerpDouble(
        movieCardLoaderStrokeWidth,
        other.movieCardLoaderStrokeWidth,
        t,
      )!,
      movieCardStatusBadgeSize: lerpDouble(
        movieCardStatusBadgeSize,
        other.movieCardStatusBadgeSize,
        t,
      )!,
      movieDetailHeroHeight:
          lerpDouble(movieDetailHeroHeight, other.movieDetailHeroHeight, t)!,
      movieDetailThinCoverWidth: lerpDouble(
        movieDetailThinCoverWidth,
        other.movieDetailThinCoverWidth,
        t,
      )!,
      movieDetailPlotThumbnailWidth: lerpDouble(
        movieDetailPlotThumbnailWidth,
        other.movieDetailPlotThumbnailWidth,
        t,
      )!,
      movieDetailPlotThumbnailHeight: lerpDouble(
        movieDetailPlotThumbnailHeight,
        other.movieDetailPlotThumbnailHeight,
        t,
      )!,
      movieDetailActorAvatarSize: lerpDouble(
        movieDetailActorAvatarSize,
        other.movieDetailActorAvatarSize,
        t,
      )!,
      movieDetailActorCardWidth: lerpDouble(
        movieDetailActorCardWidth,
        other.movieDetailActorCardWidth,
        t,
      )!,
      movieDetailSectionGap:
          lerpDouble(movieDetailSectionGap, other.movieDetailSectionGap, t)!,
      movieDetailSectionTitleGap: lerpDouble(
        movieDetailSectionTitleGap,
        other.movieDetailSectionTitleGap,
        t,
      )!,
      movieDetailPillHorizontalPadding: lerpDouble(
        movieDetailPillHorizontalPadding,
        other.movieDetailPillHorizontalPadding,
        t,
      )!,
      movieDetailPillVerticalPadding: lerpDouble(
        movieDetailPillVerticalPadding,
        other.movieDetailPillVerticalPadding,
        t,
      )!,
      movieDetailPillGap:
          lerpDouble(movieDetailPillGap, other.movieDetailPillGap, t)!,
      movieDetailBottomBarMinHeight: lerpDouble(
        movieDetailBottomBarMinHeight,
        other.movieDetailBottomBarMinHeight,
        t,
      )!,
      movieDetailMediaRowMinHeight: lerpDouble(
        movieDetailMediaRowMinHeight,
        other.movieDetailMediaRowMinHeight,
        t,
      )!,
      movieDetailMoreEntryHeight: lerpDouble(
        movieDetailMoreEntryHeight,
        other.movieDetailMoreEntryHeight,
        t,
      )!,
      movieDetailDialogWidth:
          lerpDouble(movieDetailDialogWidth, other.movieDetailDialogWidth, t)!,
      movieDetailDialogMinHeight: lerpDouble(
        movieDetailDialogMinHeight,
        other.movieDetailDialogMinHeight,
        t,
      )!,
      movieDetailPlotPreviewMaxWidth: lerpDouble(
        movieDetailPlotPreviewMaxWidth,
        other.movieDetailPlotPreviewMaxWidth,
        t,
      )!,
      movieDetailPlotPreviewMaxHeight: lerpDouble(
        movieDetailPlotPreviewMaxHeight,
        other.movieDetailPlotPreviewMaxHeight,
        t,
      )!,
      movieDetailPlotPreviewThumbnailWidth: lerpDouble(
        movieDetailPlotPreviewThumbnailWidth,
        other.movieDetailPlotPreviewThumbnailWidth,
        t,
      )!,
      movieDetailPlotPreviewThumbnailHeight: lerpDouble(
        movieDetailPlotPreviewThumbnailHeight,
        other.movieDetailPlotPreviewThumbnailHeight,
        t,
      )!,
      playlistBannerHeight:
          lerpDouble(playlistBannerHeight, other.playlistBannerHeight, t)!,
      playlistDialogWidth:
          lerpDouble(playlistDialogWidth, other.playlistDialogWidth, t)!,
      mobileBottomNavHeight:
          lerpDouble(mobileBottomNavHeight, other.mobileBottomNavHeight, t)!,
      mobileTopTabHeight:
          lerpDouble(mobileTopTabHeight, other.mobileTopTabHeight, t)!,
      mobileSubpageLeadingWidth: lerpDouble(
        mobileSubpageLeadingWidth,
        other.mobileSubpageLeadingWidth,
        t,
      )!,
      mobileLatestMovieCardWidth: lerpDouble(
        mobileLatestMovieCardWidth,
        other.mobileLatestMovieCardWidth,
        t,
      )!,
      mobileFollowMovieCardHeight: lerpDouble(
        mobileFollowMovieCardHeight,
        other.mobileFollowMovieCardHeight,
        t,
      )!,
      mobileFollowMovieThinCoverWidth: lerpDouble(
        mobileFollowMovieThinCoverWidth,
        other.mobileFollowMovieThinCoverWidth,
        t,
      )!,
      mobileFollowMovieStillWidth: lerpDouble(
        mobileFollowMovieStillWidth,
        other.mobileFollowMovieStillWidth,
        t,
      )!,
      moviePlayerThumbnailAspectRatio: lerpDouble(
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
