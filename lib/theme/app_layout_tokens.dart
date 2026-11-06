import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppLayoutTokens extends ThemeExtension<AppLayoutTokens> {
  const AppLayoutTokens({
    required this.inlineActionButtonSize,
    required this.panelIconContainerSize,
    required this.segmentedControlHeight,
    required this.filterFieldWidthSm,
    required this.filterFieldWidthMd,
    required this.filterFieldWidthLg,
    required this.filterFieldWidthXl,
    required this.dialogWidthSm,
    required this.dialogWidthMd,
    required this.dialogInsetPadding,
    required this.emptySectionVerticalPadding,
    required this.inlineIconPadding,
    required this.directoryBrowserHeight,
    required this.qrImageSize,
    required this.breakpointMinContent,
    required this.breakpointCardCompact,
    required this.breakpointCompact,
    required this.breakpointMedium,
    required this.breakpointWide,
    required this.breakpointDesktop,
    required this.searchFieldWidth,
  });

  const AppLayoutTokens.defaults()
    : inlineActionButtonSize = 32,
      panelIconContainerSize = 48,
      segmentedControlHeight = 42,
      filterFieldWidthSm = 160,
      filterFieldWidthMd = 180,
      filterFieldWidthLg = 200,
      filterFieldWidthXl = 220,
      dialogWidthSm = 420,
      dialogWidthMd = 520,
      dialogInsetPadding = 24,
      emptySectionVerticalPadding = 48,
      inlineIconPadding = 5,
      directoryBrowserHeight = 280,
      qrImageSize = 224,
      breakpointMinContent = 320,
      breakpointCardCompact = 340,
      breakpointCompact = 420,
      breakpointMedium = 520,
      breakpointWide = 640,
      breakpointDesktop = 980,
      searchFieldWidth = 360;

  final double inlineActionButtonSize;
  final double panelIconContainerSize;
  final double segmentedControlHeight;
  final double filterFieldWidthSm;
  final double filterFieldWidthMd;
  final double filterFieldWidthLg;
  final double filterFieldWidthXl;
  final double dialogWidthSm;
  final double dialogWidthMd;
  final double dialogInsetPadding;
  final double emptySectionVerticalPadding;
  final double inlineIconPadding;

  /// 媒体导入弹窗内目录浏览器的固定视窗高度，保证在最小分辨率下也能显示 ≥5 行条目。
  final double directoryBrowserHeight;

  /// 二维码图像的正方形边长（用于需要扫码授权的配置场景）。
  final double qrImageSize;

  /// 页面内容可用的最小宽度；低于它时优先压缩留白而不是继续分栏。
  final double breakpointMinContent;

  /// 卡片内部从常规布局切到紧凑布局的宽度阈值。
  final double breakpointCardCompact;

  /// 页面从宽屏双列切到单列/紧凑导航的宽度阈值。
  final double breakpointCompact;

  /// 中型内容区的分栏阈值。
  final double breakpointMedium;

  /// 宽屏内容区的分栏阈值。
  final double breakpointWide;

  /// 桌面工作台布局阈值。
  final double breakpointDesktop;

  /// 搜索框在桌面筛选栏中的常规宽度。
  final double searchFieldWidth;

  @override
  AppLayoutTokens copyWith({
    double? inlineActionButtonSize,
    double? panelIconContainerSize,
    double? segmentedControlHeight,
    double? filterFieldWidthSm,
    double? filterFieldWidthMd,
    double? filterFieldWidthLg,
    double? filterFieldWidthXl,
    double? dialogWidthSm,
    double? dialogWidthMd,
    double? dialogInsetPadding,
    double? emptySectionVerticalPadding,
    double? inlineIconPadding,
    double? directoryBrowserHeight,
    double? qrImageSize,
    double? breakpointMinContent,
    double? breakpointCardCompact,
    double? breakpointCompact,
    double? breakpointMedium,
    double? breakpointWide,
    double? breakpointDesktop,
    double? searchFieldWidth,
  }) {
    return AppLayoutTokens(
      inlineActionButtonSize:
          inlineActionButtonSize ?? this.inlineActionButtonSize,
      panelIconContainerSize:
          panelIconContainerSize ?? this.panelIconContainerSize,
      segmentedControlHeight:
          segmentedControlHeight ?? this.segmentedControlHeight,
      filterFieldWidthSm: filterFieldWidthSm ?? this.filterFieldWidthSm,
      filterFieldWidthMd: filterFieldWidthMd ?? this.filterFieldWidthMd,
      filterFieldWidthLg: filterFieldWidthLg ?? this.filterFieldWidthLg,
      filterFieldWidthXl: filterFieldWidthXl ?? this.filterFieldWidthXl,
      dialogWidthSm: dialogWidthSm ?? this.dialogWidthSm,
      dialogWidthMd: dialogWidthMd ?? this.dialogWidthMd,
      dialogInsetPadding: dialogInsetPadding ?? this.dialogInsetPadding,
      emptySectionVerticalPadding:
          emptySectionVerticalPadding ?? this.emptySectionVerticalPadding,
      inlineIconPadding: inlineIconPadding ?? this.inlineIconPadding,
      directoryBrowserHeight:
          directoryBrowserHeight ?? this.directoryBrowserHeight,
      qrImageSize: qrImageSize ?? this.qrImageSize,
      breakpointMinContent: breakpointMinContent ?? this.breakpointMinContent,
      breakpointCardCompact:
          breakpointCardCompact ?? this.breakpointCardCompact,
      breakpointCompact: breakpointCompact ?? this.breakpointCompact,
      breakpointMedium: breakpointMedium ?? this.breakpointMedium,
      breakpointWide: breakpointWide ?? this.breakpointWide,
      breakpointDesktop: breakpointDesktop ?? this.breakpointDesktop,
      searchFieldWidth: searchFieldWidth ?? this.searchFieldWidth,
    );
  }

  @override
  AppLayoutTokens lerp(ThemeExtension<AppLayoutTokens>? other, double t) {
    if (other is! AppLayoutTokens) {
      return this;
    }
    return AppLayoutTokens(
      inlineActionButtonSize: lerpDouble(
        inlineActionButtonSize,
        other.inlineActionButtonSize,
        t,
      )!,
      panelIconContainerSize: lerpDouble(
        panelIconContainerSize,
        other.panelIconContainerSize,
        t,
      )!,
      segmentedControlHeight: lerpDouble(
        segmentedControlHeight,
        other.segmentedControlHeight,
        t,
      )!,
      filterFieldWidthSm: lerpDouble(
        filterFieldWidthSm,
        other.filterFieldWidthSm,
        t,
      )!,
      filterFieldWidthMd: lerpDouble(
        filterFieldWidthMd,
        other.filterFieldWidthMd,
        t,
      )!,
      filterFieldWidthLg: lerpDouble(
        filterFieldWidthLg,
        other.filterFieldWidthLg,
        t,
      )!,
      filterFieldWidthXl: lerpDouble(
        filterFieldWidthXl,
        other.filterFieldWidthXl,
        t,
      )!,
      dialogWidthSm: lerpDouble(dialogWidthSm, other.dialogWidthSm, t)!,
      dialogWidthMd: lerpDouble(dialogWidthMd, other.dialogWidthMd, t)!,
      dialogInsetPadding: lerpDouble(
        dialogInsetPadding,
        other.dialogInsetPadding,
        t,
      )!,
      emptySectionVerticalPadding: lerpDouble(
        emptySectionVerticalPadding,
        other.emptySectionVerticalPadding,
        t,
      )!,
      inlineIconPadding: lerpDouble(
        inlineIconPadding,
        other.inlineIconPadding,
        t,
      )!,
      directoryBrowserHeight: lerpDouble(
        directoryBrowserHeight,
        other.directoryBrowserHeight,
        t,
      )!,
      qrImageSize: lerpDouble(qrImageSize, other.qrImageSize, t)!,
      breakpointMinContent: lerpDouble(
        breakpointMinContent,
        other.breakpointMinContent,
        t,
      )!,
      breakpointCardCompact: lerpDouble(
        breakpointCardCompact,
        other.breakpointCardCompact,
        t,
      )!,
      breakpointCompact: lerpDouble(
        breakpointCompact,
        other.breakpointCompact,
        t,
      )!,
      breakpointMedium: lerpDouble(
        breakpointMedium,
        other.breakpointMedium,
        t,
      )!,
      breakpointWide: lerpDouble(breakpointWide, other.breakpointWide, t)!,
      breakpointDesktop: lerpDouble(
        breakpointDesktop,
        other.breakpointDesktop,
        t,
      )!,
      searchFieldWidth: lerpDouble(
        searchFieldWidth,
        other.searchFieldWidth,
        t,
      )!,
    );
  }
}

extension AppLayoutTokensThemeDataX on ThemeData {
  AppLayoutTokens get appLayoutTokens =>
      extension<AppLayoutTokens>() ?? const AppLayoutTokens.defaults();
}

extension AppLayoutTokensBuildContextX on BuildContext {
  AppLayoutTokens get appLayoutTokens => Theme.of(this).appLayoutTokens;
}
