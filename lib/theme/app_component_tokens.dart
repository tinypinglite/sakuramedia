import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppComponentTokens extends ThemeExtension<AppComponentTokens> {
  /// 全站卡片网格统一规格：目标列宽与列数上限。
  ///
  /// 列表页、合集列表和合集详情都从这里取值（桌面/移动两套构造器共用）。调整
  /// 卡片密度时只改这两个常量，界面其余部分不需要再动。
  static const double defaultCardGridTargetWidth = 220;
  static const int defaultCardGridMaxColumns = 8;

  const AppComponentTokens({
    required this.desktopTitleBarHeight,
    required this.desktopMacTrafficLightInsetWidth,
    required this.desktopTitleBarControlGap,
    required this.movieCardTargetWidth,
    required this.movieThumbnailTargetWidth,
    required this.movieCardAspectRatio,
    required this.cardGridTargetWidth,
    required this.cardGridMaxColumns,
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
    required this.switchTrackWidth,
    required this.switchTrackHeight,
    required this.switchThumbDiameter,
    required this.movieCardLoaderSize,
    required this.movieCardLoaderStrokeWidth,
    required this.movieCardStatusBadgeSize,
    required this.subscriptionHeartHitSize,
    required this.downloadTaskCoverWidth,
    required this.importMetadataCandidateCoverWidth,
    required this.importMetadataCandidateCoverHeight,
    required this.downloadTaskCardMinHeight,
    required this.downloadTaskProgressHeight,
    required this.listRowCoverWidth,
    required this.listRowCoverHeight,
    required this.listGroupHeaderCoverWidth,
    required this.listGroupHeaderCoverHeight,
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
    required this.clipPlayerDialogWidth,
    required this.mobileBottomNavHeight,
    required this.mobileTopTabHeight,
    required this.mobileFilterEntryMaxLabelWidth,
    required this.mobileSubpageLeadingWidth,
    required this.mobileLatestMovieCardWidth,
    required this.mobileFollowMovieCardHeight,
    required this.mobileFollowMovieThinCoverWidth,
    required this.moviePlayerThumbnailAspectRatio,
  });

  const AppComponentTokens.defaults()
    : desktopTitleBarHeight = 56,
      desktopMacTrafficLightInsetWidth = 52,
      desktopTitleBarControlGap = 8,
      movieCardTargetWidth = 220,
      movieThumbnailTargetWidth = 128,
      movieCardAspectRatio = 0.7,
      cardGridTargetWidth = defaultCardGridTargetWidth,
      cardGridMaxColumns = defaultCardGridMaxColumns,
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
      switchTrackWidth = 36,
      switchTrackHeight = 20,
      switchThumbDiameter = 16,
      movieCardLoaderSize = 18,
      movieCardLoaderStrokeWidth = 2,
      movieCardStatusBadgeSize = 24,
      subscriptionHeartHitSize = 44,
      downloadTaskCoverWidth = 220,
      importMetadataCandidateCoverWidth = 160,
      importMetadataCandidateCoverHeight = 90,
      downloadTaskCardMinHeight = 120,
      downloadTaskProgressHeight = 6,
      // 列表行卡（媒体管理 / 订阅管理）左侧封面：桌面 16:9 宽图，移动窄竖图。
      listRowCoverWidth = 234,
      listRowCoverHeight = 132,
      // 分组卡组头的小缩略图：与行卡区分层级，桌面 16:9、移动略小的 16:9。
      listGroupHeaderCoverWidth = 120,
      listGroupHeaderCoverHeight = 68,
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
      clipPlayerDialogWidth = 880,
      mobileBottomNavHeight = 52,
      mobileTopTabHeight = 44,
      mobileFilterEntryMaxLabelWidth = 140,
      mobileSubpageLeadingWidth = 40,
      mobileLatestMovieCardWidth = 142,
      mobileFollowMovieCardHeight = 150,
      mobileFollowMovieThinCoverWidth = 96,
      moviePlayerThumbnailAspectRatio = 16 / 9;

  const AppComponentTokens.mobile()
    : desktopTitleBarHeight = 56,
      desktopMacTrafficLightInsetWidth = 52,
      desktopTitleBarControlGap = 8,
      movieCardTargetWidth = 220,
      movieThumbnailTargetWidth = 128,
      movieCardAspectRatio = 0.7,
      cardGridTargetWidth = defaultCardGridTargetWidth,
      cardGridMaxColumns = defaultCardGridMaxColumns,
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
      switchTrackWidth = 44,
      switchTrackHeight = 24,
      switchThumbDiameter = 18,
      movieCardLoaderSize = 18,
      movieCardLoaderStrokeWidth = 2,
      movieCardStatusBadgeSize = 24,
      subscriptionHeartHitSize = 44,
      downloadTaskCoverWidth = 96,
      importMetadataCandidateCoverWidth = 128,
      importMetadataCandidateCoverHeight = 72,
      downloadTaskCardMinHeight = 120,
      downloadTaskProgressHeight = 6,
      listRowCoverWidth = 92,
      listRowCoverHeight = 132,
      listGroupHeaderCoverWidth = 96,
      listGroupHeaderCoverHeight = 54,
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
      clipPlayerDialogWidth = 880,
      mobileBottomNavHeight = 56,
      mobileTopTabHeight = 44,
      mobileFilterEntryMaxLabelWidth = 140,
      mobileSubpageLeadingWidth = 44,
      mobileLatestMovieCardWidth = 148,
      mobileFollowMovieCardHeight = 158,
      mobileFollowMovieThinCoverWidth = 100,
      moviePlayerThumbnailAspectRatio = 16 / 9;

  final double desktopTitleBarHeight;
  final double desktopMacTrafficLightInsetWidth;
  final double desktopTitleBarControlGap;
  final double movieCardTargetWidth;
  final double movieThumbnailTargetWidth;
  final double movieCardAspectRatio;

  /// 卡片网格（列表页 / 合集列表 / 合集详情）统一目标列宽。
  final double cardGridTargetWidth;

  /// 卡片网格统一列数上限。
  final int cardGridMaxColumns;
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

  /// 紧凑启停开关（[AppSwitch]）的轨道宽 / 轨道高 / 拇指直径。
  final double switchTrackWidth;
  final double switchTrackHeight;
  final double switchThumbDiameter;

  final double movieCardLoaderSize;
  final double movieCardLoaderStrokeWidth;
  final double movieCardStatusBadgeSize;

  /// 订阅心形等小图标的命中区尺寸：视觉图标保持 24，外层点击区扩大到该值。
  final double subscriptionHeartHitSize;
  final double downloadTaskCoverWidth;

  /// 导入失败项「手动匹配」候选行的 16:9 宽图封面尺寸。
  final double importMetadataCandidateCoverWidth;
  final double importMetadataCandidateCoverHeight;
  final double downloadTaskCardMinHeight;
  final double downloadTaskProgressHeight;

  /// 列表行卡（媒体管理 / 订阅管理）左侧封面尺寸（桌面 / 移动分档）。
  /// 封面贴左整高、由行卡圆角裁剪；桌面 16:9 宽图、移动窄竖图。
  final double listRowCoverWidth;
  final double listRowCoverHeight;

  /// 分组卡组头的小缩略图尺寸（桌面 / 移动分档），与行卡封面区分层级。
  final double listGroupHeaderCoverWidth;
  final double listGroupHeaderCoverHeight;

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
  final double clipPlayerDialogWidth;
  final double mobileBottomNavHeight;
  final double mobileTopTabHeight;

  /// 顶栏筛选入口里筛选摘要的最大宽度，超出省略号，避免挤掉右侧信息/操作。
  final double mobileFilterEntryMaxLabelWidth;
  final double mobileSubpageLeadingWidth;
  final double mobileLatestMovieCardWidth;
  final double mobileFollowMovieCardHeight;
  final double mobileFollowMovieThinCoverWidth;
  final double moviePlayerThumbnailAspectRatio;

  @override
  AppComponentTokens copyWith({
    double? desktopTitleBarHeight,
    double? desktopMacTrafficLightInsetWidth,
    double? desktopTitleBarControlGap,
    double? movieCardTargetWidth,
    double? movieThumbnailTargetWidth,
    double? movieCardAspectRatio,
    double? cardGridTargetWidth,
    int? cardGridMaxColumns,
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
    double? switchTrackWidth,
    double? switchTrackHeight,
    double? switchThumbDiameter,
    double? movieCardLoaderSize,
    double? movieCardLoaderStrokeWidth,
    double? movieCardStatusBadgeSize,
    double? subscriptionHeartHitSize,
    double? downloadTaskCoverWidth,
    double? importMetadataCandidateCoverWidth,
    double? importMetadataCandidateCoverHeight,
    double? downloadTaskCardMinHeight,
    double? downloadTaskProgressHeight,
    double? listRowCoverWidth,
    double? listRowCoverHeight,
    double? listGroupHeaderCoverWidth,
    double? listGroupHeaderCoverHeight,
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
    double? clipPlayerDialogWidth,
    double? mobileBottomNavHeight,
    double? mobileTopTabHeight,
    double? mobileFilterEntryMaxLabelWidth,
    double? mobileSubpageLeadingWidth,
    double? mobileLatestMovieCardWidth,
    double? mobileFollowMovieCardHeight,
    double? mobileFollowMovieThinCoverWidth,
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
      movieCardTargetWidth: movieCardTargetWidth ?? this.movieCardTargetWidth,
      movieThumbnailTargetWidth:
          movieThumbnailTargetWidth ?? this.movieThumbnailTargetWidth,
      movieCardAspectRatio: movieCardAspectRatio ?? this.movieCardAspectRatio,
      cardGridTargetWidth: cardGridTargetWidth ?? this.cardGridTargetWidth,
      cardGridMaxColumns: cardGridMaxColumns ?? this.cardGridMaxColumns,
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
      switchTrackWidth: switchTrackWidth ?? this.switchTrackWidth,
      switchTrackHeight: switchTrackHeight ?? this.switchTrackHeight,
      switchThumbDiameter: switchThumbDiameter ?? this.switchThumbDiameter,
      movieCardLoaderSize: movieCardLoaderSize ?? this.movieCardLoaderSize,
      movieCardLoaderStrokeWidth:
          movieCardLoaderStrokeWidth ?? this.movieCardLoaderStrokeWidth,
      movieCardStatusBadgeSize:
          movieCardStatusBadgeSize ?? this.movieCardStatusBadgeSize,
      subscriptionHeartHitSize:
          subscriptionHeartHitSize ?? this.subscriptionHeartHitSize,
      downloadTaskCoverWidth:
          downloadTaskCoverWidth ?? this.downloadTaskCoverWidth,
      importMetadataCandidateCoverWidth:
          importMetadataCandidateCoverWidth ??
          this.importMetadataCandidateCoverWidth,
      importMetadataCandidateCoverHeight:
          importMetadataCandidateCoverHeight ??
          this.importMetadataCandidateCoverHeight,
      downloadTaskCardMinHeight:
          downloadTaskCardMinHeight ?? this.downloadTaskCardMinHeight,
      downloadTaskProgressHeight:
          downloadTaskProgressHeight ?? this.downloadTaskProgressHeight,
      listRowCoverWidth: listRowCoverWidth ?? this.listRowCoverWidth,
      listRowCoverHeight: listRowCoverHeight ?? this.listRowCoverHeight,
      listGroupHeaderCoverWidth:
          listGroupHeaderCoverWidth ?? this.listGroupHeaderCoverWidth,
      listGroupHeaderCoverHeight:
          listGroupHeaderCoverHeight ?? this.listGroupHeaderCoverHeight,
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
      clipPlayerDialogWidth:
          clipPlayerDialogWidth ?? this.clipPlayerDialogWidth,
      mobileBottomNavHeight:
          mobileBottomNavHeight ?? this.mobileBottomNavHeight,
      mobileTopTabHeight: mobileTopTabHeight ?? this.mobileTopTabHeight,
      mobileFilterEntryMaxLabelWidth:
          mobileFilterEntryMaxLabelWidth ?? this.mobileFilterEntryMaxLabelWidth,
      mobileSubpageLeadingWidth:
          mobileSubpageLeadingWidth ?? this.mobileSubpageLeadingWidth,
      mobileLatestMovieCardWidth:
          mobileLatestMovieCardWidth ?? this.mobileLatestMovieCardWidth,
      mobileFollowMovieCardHeight:
          mobileFollowMovieCardHeight ?? this.mobileFollowMovieCardHeight,
      mobileFollowMovieThinCoverWidth:
          mobileFollowMovieThinCoverWidth ??
          this.mobileFollowMovieThinCoverWidth,
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
      desktopTitleBarHeight: lerpDouble(
        desktopTitleBarHeight,
        other.desktopTitleBarHeight,
        t,
      )!,
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

      movieCardTargetWidth: lerpDouble(
        movieCardTargetWidth,
        other.movieCardTargetWidth,
        t,
      )!,
      movieThumbnailTargetWidth: lerpDouble(
        movieThumbnailTargetWidth,
        other.movieThumbnailTargetWidth,
        t,
      )!,
      movieCardAspectRatio: lerpDouble(
        movieCardAspectRatio,
        other.movieCardAspectRatio,
        t,
      )!,
      cardGridTargetWidth: lerpDouble(
        cardGridTargetWidth,
        other.cardGridTargetWidth,
        t,
      )!,
      cardGridMaxColumns: lerpDouble(
        cardGridMaxColumns.toDouble(),
        other.cardGridMaxColumns.toDouble(),
        t,
      )!.round(),
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
      switchTrackWidth: lerpDouble(
        switchTrackWidth,
        other.switchTrackWidth,
        t,
      )!,
      switchTrackHeight: lerpDouble(
        switchTrackHeight,
        other.switchTrackHeight,
        t,
      )!,
      switchThumbDiameter: lerpDouble(
        switchThumbDiameter,
        other.switchThumbDiameter,
        t,
      )!,
      movieCardLoaderSize: lerpDouble(
        movieCardLoaderSize,
        other.movieCardLoaderSize,
        t,
      )!,
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
      subscriptionHeartHitSize: lerpDouble(
        subscriptionHeartHitSize,
        other.subscriptionHeartHitSize,
        t,
      )!,
      downloadTaskCoverWidth: lerpDouble(
        downloadTaskCoverWidth,
        other.downloadTaskCoverWidth,
        t,
      )!,
      importMetadataCandidateCoverWidth: lerpDouble(
        importMetadataCandidateCoverWidth,
        other.importMetadataCandidateCoverWidth,
        t,
      )!,
      importMetadataCandidateCoverHeight: lerpDouble(
        importMetadataCandidateCoverHeight,
        other.importMetadataCandidateCoverHeight,
        t,
      )!,
      downloadTaskCardMinHeight: lerpDouble(
        downloadTaskCardMinHeight,
        other.downloadTaskCardMinHeight,
        t,
      )!,
      downloadTaskProgressHeight: lerpDouble(
        downloadTaskProgressHeight,
        other.downloadTaskProgressHeight,
        t,
      )!,
      listRowCoverWidth: lerpDouble(
        listRowCoverWidth,
        other.listRowCoverWidth,
        t,
      )!,
      listRowCoverHeight: lerpDouble(
        listRowCoverHeight,
        other.listRowCoverHeight,
        t,
      )!,
      listGroupHeaderCoverWidth: lerpDouble(
        listGroupHeaderCoverWidth,
        other.listGroupHeaderCoverWidth,
        t,
      )!,
      listGroupHeaderCoverHeight: lerpDouble(
        listGroupHeaderCoverHeight,
        other.listGroupHeaderCoverHeight,
        t,
      )!,
      movieDetailHeroHeight: lerpDouble(
        movieDetailHeroHeight,
        other.movieDetailHeroHeight,
        t,
      )!,
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
      movieDetailSectionGap: lerpDouble(
        movieDetailSectionGap,
        other.movieDetailSectionGap,
        t,
      )!,
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
      movieDetailPillGap: lerpDouble(
        movieDetailPillGap,
        other.movieDetailPillGap,
        t,
      )!,
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
      movieDetailDialogWidth: lerpDouble(
        movieDetailDialogWidth,
        other.movieDetailDialogWidth,
        t,
      )!,
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
      playlistBannerHeight: lerpDouble(
        playlistBannerHeight,
        other.playlistBannerHeight,
        t,
      )!,
      playlistDialogWidth: lerpDouble(
        playlistDialogWidth,
        other.playlistDialogWidth,
        t,
      )!,
      clipPlayerDialogWidth: lerpDouble(
        clipPlayerDialogWidth,
        other.clipPlayerDialogWidth,
        t,
      )!,
      mobileBottomNavHeight: lerpDouble(
        mobileBottomNavHeight,
        other.mobileBottomNavHeight,
        t,
      )!,
      mobileTopTabHeight: lerpDouble(
        mobileTopTabHeight,
        other.mobileTopTabHeight,
        t,
      )!,
      mobileFilterEntryMaxLabelWidth: lerpDouble(
        mobileFilterEntryMaxLabelWidth,
        other.mobileFilterEntryMaxLabelWidth,
        t,
      )!,
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
