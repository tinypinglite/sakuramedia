import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

@immutable
class AppOverlayTokens extends ThemeExtension<AppOverlayTokens> {
  const AppOverlayTokens({
    required this.surfaceRadius,
    required this.surfaceBorderAlpha,
    required this.surfaceShadowAlpha,
    required this.surfaceShadowBlur,
    required this.surfaceShadowOffsetY,
    required this.glassSurfaceAlpha,
    required this.glassBlurSigma,
    required this.hoverAlpha,
    required this.pressAlpha,
    required this.primaryLabelAlpha,
    required this.mutedLabelAlpha,
    required this.switchTrackAlpha,
    required this.menuVerticalPadding,
    required this.drawerVerticalPadding,
    required this.menuGap,
    required this.menuItemHeight,
    required this.controlMinWidth,
    required this.controlMinHeight,
    required this.controlHorizontalPadding,
    required this.controlVerticalPadding,
    required this.controlSideGap,
    required this.controlTrailingGap,
    required this.controlCheckSlotWidth,
    required this.controlCheckIconSize,
    required this.menuWidthSm,
    required this.menuWidthMd,
    required this.playerDrawerWidth,
    required this.playerInfoDrawerWidth,
    required this.playerDrawerHorizontalInset,
    required this.playerControlBarHorizontalInset,
    required this.playerControlBarTopInset,
    required this.playerSeekBarHorizontalInset,
    required this.playerSeekBarBottomInset,
    required this.playerBackBadgeMaxWidth,
    required this.playerBackBadgeMinHeight,
    required this.playerBackOverlayTop,
    required this.playerBackOverlayLeft,
  });

  const AppOverlayTokens.defaults()
    : surfaceRadius = 18,
      surfaceBorderAlpha = 0.12,
      surfaceShadowAlpha = 0.22,
      surfaceShadowBlur = 18,
      surfaceShadowOffsetY = 8,
      glassSurfaceAlpha = 0.6,
      glassBlurSigma = 30,
      hoverAlpha = 0.08,
      pressAlpha = 0.12,
      primaryLabelAlpha = 0.94,
      mutedLabelAlpha = 0.85,
      switchTrackAlpha = 0.28,
      menuVerticalPadding = 6,
      drawerVerticalPadding = 8,
      menuGap = 6,
      menuItemHeight = 40,
      controlMinWidth = 48,
      controlMinHeight = 34,
      controlHorizontalPadding = 6,
      controlVerticalPadding = 4,
      controlSideGap = 14,
      controlTrailingGap = 14,
      controlCheckSlotWidth = 24,
      controlCheckIconSize = 18,
      menuWidthSm = 144,
      menuWidthMd = 188,
      playerDrawerWidth = 196,
      playerInfoDrawerWidth = 360,
      playerDrawerHorizontalInset = 10,
      playerControlBarHorizontalInset = 12,
      playerControlBarTopInset = 18,
      playerSeekBarHorizontalInset = 30,
      playerSeekBarBottomInset = 75,
      playerBackBadgeMaxWidth = 280,
      playerBackBadgeMinHeight = 44,
      playerBackOverlayTop = 24,
      playerBackOverlayLeft = 12;

  final double surfaceRadius;
  final double surfaceBorderAlpha;
  final double surfaceShadowAlpha;
  final double surfaceShadowBlur;
  final double surfaceShadowOffsetY;
  final double glassSurfaceAlpha;
  final double glassBlurSigma;

  /// hover 叠色透明度，目前由主题给 Material 内置控件兜底，以及登录页、
  /// 下拉选择、播放器浮层等自绘 hover 使用。自研可点组件（AppInteractiveSurface）
  /// 不做 hover 底色。
  final double hoverAlpha;

  /// 按下态叠加的中性色透明度，主题用它给 Material 内置控件的 overlayColor
  /// 兜底；自研可点组件的按下反馈是整体变淡，见 `app_interactive_surface.dart`。
  final double pressAlpha;

  final double primaryLabelAlpha;
  final double mutedLabelAlpha;

  /// 媒体浮层上 [AppSwitch] 关闭态轨道的白色透明度。
  final double switchTrackAlpha;
  final double menuVerticalPadding;
  final double drawerVerticalPadding;
  final double menuGap;
  final double menuItemHeight;
  final double controlMinWidth;
  final double controlMinHeight;
  final double controlHorizontalPadding;
  final double controlVerticalPadding;
  final double controlSideGap;
  final double controlTrailingGap;
  final double controlCheckSlotWidth;
  final double controlCheckIconSize;
  final double menuWidthSm;
  final double menuWidthMd;
  final double playerDrawerWidth;
  final double playerInfoDrawerWidth;
  final double playerDrawerHorizontalInset;
  final double playerControlBarHorizontalInset;
  final double playerControlBarTopInset;
  final double playerSeekBarHorizontalInset;
  final double playerSeekBarBottomInset;
  final double playerBackBadgeMaxWidth;
  final double playerBackBadgeMinHeight;
  final double playerBackOverlayTop;
  final double playerBackOverlayLeft;

  BorderRadius get surfaceBorderRadius => BorderRadius.circular(surfaceRadius);

  @override
  AppOverlayTokens copyWith({
    double? surfaceRadius,
    double? surfaceBorderAlpha,
    double? surfaceShadowAlpha,
    double? surfaceShadowBlur,
    double? surfaceShadowOffsetY,
    double? glassSurfaceAlpha,
    double? glassBlurSigma,
    double? hoverAlpha,
    double? pressAlpha,
    double? primaryLabelAlpha,
    double? mutedLabelAlpha,
    double? switchTrackAlpha,
    double? menuVerticalPadding,
    double? drawerVerticalPadding,
    double? menuGap,
    double? menuItemHeight,
    double? controlMinWidth,
    double? controlMinHeight,
    double? controlHorizontalPadding,
    double? controlVerticalPadding,
    double? controlSideGap,
    double? controlTrailingGap,
    double? controlCheckSlotWidth,
    double? controlCheckIconSize,
    double? menuWidthSm,
    double? menuWidthMd,
    double? playerDrawerWidth,
    double? playerInfoDrawerWidth,
    double? playerDrawerHorizontalInset,
    double? playerControlBarHorizontalInset,
    double? playerControlBarTopInset,
    double? playerSeekBarHorizontalInset,
    double? playerSeekBarBottomInset,
    double? playerBackBadgeMaxWidth,
    double? playerBackBadgeMinHeight,
    double? playerBackOverlayTop,
    double? playerBackOverlayLeft,
  }) {
    return AppOverlayTokens(
      surfaceRadius: surfaceRadius ?? this.surfaceRadius,
      surfaceBorderAlpha: surfaceBorderAlpha ?? this.surfaceBorderAlpha,
      surfaceShadowAlpha: surfaceShadowAlpha ?? this.surfaceShadowAlpha,
      surfaceShadowBlur: surfaceShadowBlur ?? this.surfaceShadowBlur,
      surfaceShadowOffsetY: surfaceShadowOffsetY ?? this.surfaceShadowOffsetY,
      glassSurfaceAlpha: glassSurfaceAlpha ?? this.glassSurfaceAlpha,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      hoverAlpha: hoverAlpha ?? this.hoverAlpha,
      pressAlpha: pressAlpha ?? this.pressAlpha,
      primaryLabelAlpha: primaryLabelAlpha ?? this.primaryLabelAlpha,
      mutedLabelAlpha: mutedLabelAlpha ?? this.mutedLabelAlpha,
      switchTrackAlpha: switchTrackAlpha ?? this.switchTrackAlpha,
      menuVerticalPadding: menuVerticalPadding ?? this.menuVerticalPadding,
      drawerVerticalPadding:
          drawerVerticalPadding ?? this.drawerVerticalPadding,
      menuGap: menuGap ?? this.menuGap,
      menuItemHeight: menuItemHeight ?? this.menuItemHeight,
      controlMinWidth: controlMinWidth ?? this.controlMinWidth,
      controlMinHeight: controlMinHeight ?? this.controlMinHeight,
      controlHorizontalPadding:
          controlHorizontalPadding ?? this.controlHorizontalPadding,
      controlVerticalPadding:
          controlVerticalPadding ?? this.controlVerticalPadding,
      controlSideGap: controlSideGap ?? this.controlSideGap,
      controlTrailingGap: controlTrailingGap ?? this.controlTrailingGap,
      controlCheckSlotWidth:
          controlCheckSlotWidth ?? this.controlCheckSlotWidth,
      controlCheckIconSize: controlCheckIconSize ?? this.controlCheckIconSize,
      menuWidthSm: menuWidthSm ?? this.menuWidthSm,
      menuWidthMd: menuWidthMd ?? this.menuWidthMd,
      playerDrawerWidth: playerDrawerWidth ?? this.playerDrawerWidth,
      playerInfoDrawerWidth:
          playerInfoDrawerWidth ?? this.playerInfoDrawerWidth,
      playerDrawerHorizontalInset:
          playerDrawerHorizontalInset ?? this.playerDrawerHorizontalInset,
      playerControlBarHorizontalInset:
          playerControlBarHorizontalInset ??
          this.playerControlBarHorizontalInset,
      playerControlBarTopInset:
          playerControlBarTopInset ?? this.playerControlBarTopInset,
      playerSeekBarHorizontalInset:
          playerSeekBarHorizontalInset ?? this.playerSeekBarHorizontalInset,
      playerSeekBarBottomInset:
          playerSeekBarBottomInset ?? this.playerSeekBarBottomInset,
      playerBackBadgeMaxWidth:
          playerBackBadgeMaxWidth ?? this.playerBackBadgeMaxWidth,
      playerBackBadgeMinHeight:
          playerBackBadgeMinHeight ?? this.playerBackBadgeMinHeight,
      playerBackOverlayTop: playerBackOverlayTop ?? this.playerBackOverlayTop,
      playerBackOverlayLeft:
          playerBackOverlayLeft ?? this.playerBackOverlayLeft,
    );
  }

  @override
  AppOverlayTokens lerp(ThemeExtension<AppOverlayTokens>? other, double t) {
    if (other is! AppOverlayTokens) {
      return this;
    }
    return AppOverlayTokens(
      surfaceRadius: lerpDouble(surfaceRadius, other.surfaceRadius, t)!,
      surfaceBorderAlpha:
          lerpDouble(surfaceBorderAlpha, other.surfaceBorderAlpha, t)!,
      surfaceShadowAlpha:
          lerpDouble(surfaceShadowAlpha, other.surfaceShadowAlpha, t)!,
      surfaceShadowBlur:
          lerpDouble(surfaceShadowBlur, other.surfaceShadowBlur, t)!,
      surfaceShadowOffsetY:
          lerpDouble(surfaceShadowOffsetY, other.surfaceShadowOffsetY, t)!,
      glassSurfaceAlpha:
          lerpDouble(glassSurfaceAlpha, other.glassSurfaceAlpha, t)!,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
      hoverAlpha: lerpDouble(hoverAlpha, other.hoverAlpha, t)!,
      pressAlpha: lerpDouble(pressAlpha, other.pressAlpha, t)!,
      primaryLabelAlpha:
          lerpDouble(primaryLabelAlpha, other.primaryLabelAlpha, t)!,
      mutedLabelAlpha: lerpDouble(mutedLabelAlpha, other.mutedLabelAlpha, t)!,
      switchTrackAlpha:
          lerpDouble(switchTrackAlpha, other.switchTrackAlpha, t)!,
      menuVerticalPadding:
          lerpDouble(menuVerticalPadding, other.menuVerticalPadding, t)!,
      drawerVerticalPadding:
          lerpDouble(drawerVerticalPadding, other.drawerVerticalPadding, t)!,
      menuGap: lerpDouble(menuGap, other.menuGap, t)!,
      menuItemHeight: lerpDouble(menuItemHeight, other.menuItemHeight, t)!,
      controlMinWidth: lerpDouble(controlMinWidth, other.controlMinWidth, t)!,
      controlMinHeight:
          lerpDouble(controlMinHeight, other.controlMinHeight, t)!,
      controlHorizontalPadding:
          lerpDouble(
            controlHorizontalPadding,
            other.controlHorizontalPadding,
            t,
          )!,
      controlVerticalPadding:
          lerpDouble(controlVerticalPadding, other.controlVerticalPadding, t)!,
      controlSideGap: lerpDouble(controlSideGap, other.controlSideGap, t)!,
      controlTrailingGap:
          lerpDouble(controlTrailingGap, other.controlTrailingGap, t)!,
      controlCheckSlotWidth:
          lerpDouble(controlCheckSlotWidth, other.controlCheckSlotWidth, t)!,
      controlCheckIconSize:
          lerpDouble(controlCheckIconSize, other.controlCheckIconSize, t)!,
      menuWidthSm: lerpDouble(menuWidthSm, other.menuWidthSm, t)!,
      menuWidthMd: lerpDouble(menuWidthMd, other.menuWidthMd, t)!,
      playerDrawerWidth:
          lerpDouble(playerDrawerWidth, other.playerDrawerWidth, t)!,
      playerInfoDrawerWidth:
          lerpDouble(playerInfoDrawerWidth, other.playerInfoDrawerWidth, t)!,
      playerDrawerHorizontalInset:
          lerpDouble(
            playerDrawerHorizontalInset,
            other.playerDrawerHorizontalInset,
            t,
          )!,
      playerControlBarHorizontalInset:
          lerpDouble(
            playerControlBarHorizontalInset,
            other.playerControlBarHorizontalInset,
            t,
          )!,
      playerControlBarTopInset:
          lerpDouble(
            playerControlBarTopInset,
            other.playerControlBarTopInset,
            t,
          )!,
      playerSeekBarHorizontalInset:
          lerpDouble(
            playerSeekBarHorizontalInset,
            other.playerSeekBarHorizontalInset,
            t,
          )!,
      playerSeekBarBottomInset:
          lerpDouble(
            playerSeekBarBottomInset,
            other.playerSeekBarBottomInset,
            t,
          )!,
      playerBackBadgeMaxWidth:
          lerpDouble(
            playerBackBadgeMaxWidth,
            other.playerBackBadgeMaxWidth,
            t,
          )!,
      playerBackBadgeMinHeight:
          lerpDouble(
            playerBackBadgeMinHeight,
            other.playerBackBadgeMinHeight,
            t,
          )!,
      playerBackOverlayTop:
          lerpDouble(playerBackOverlayTop, other.playerBackOverlayTop, t)!,
      playerBackOverlayLeft:
          lerpDouble(playerBackOverlayLeft, other.playerBackOverlayLeft, t)!,
    );
  }
}

extension AppOverlayTokensThemeDataX on ThemeData {
  AppOverlayTokens get appOverlayTokens =>
      extension<AppOverlayTokens>() ?? const AppOverlayTokens.defaults();
}

extension AppOverlayTokensBuildContextX on BuildContext {
  AppOverlayTokens get appOverlayTokens => Theme.of(this).appOverlayTokens;
}
