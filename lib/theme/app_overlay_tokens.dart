import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppOverlayTokens extends ThemeExtension<AppOverlayTokens> {
  const AppOverlayTokens({
    required this.surfaceRadius,
    required this.surfaceBorderAlpha,
    required this.surfaceShadowAlpha,
    required this.surfaceShadowBlur,
    required this.surfaceShadowOffsetY,
    required this.darkSurfaceAlpha,
    required this.drawerSurfaceAlpha,
    required this.infoDrawerSurfaceAlpha,
    required this.hoverAlpha,
    required this.primaryLabelAlpha,
    required this.mutedLabelAlpha,
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
      darkSurfaceAlpha = 0.84,
      drawerSurfaceAlpha = 0.9,
      infoDrawerSurfaceAlpha = 0.34,
      hoverAlpha = 0.08,
      primaryLabelAlpha = 0.94,
      mutedLabelAlpha = 0.62,
      menuVerticalPadding = 6,
      drawerVerticalPadding = 8,
      menuGap = 6,
      menuItemHeight = 40,
      controlMinWidth = 48,
      controlMinHeight = 34,
      controlHorizontalPadding = 6,
      controlVerticalPadding = 4,
      controlSideGap = 18,
      controlTrailingGap = 14,
      controlCheckSlotWidth = 28,
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
  final double darkSurfaceAlpha;
  final double drawerSurfaceAlpha;
  final double infoDrawerSurfaceAlpha;
  final double hoverAlpha;
  final double primaryLabelAlpha;
  final double mutedLabelAlpha;
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
    double? darkSurfaceAlpha,
    double? drawerSurfaceAlpha,
    double? infoDrawerSurfaceAlpha,
    double? hoverAlpha,
    double? primaryLabelAlpha,
    double? mutedLabelAlpha,
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
      darkSurfaceAlpha: darkSurfaceAlpha ?? this.darkSurfaceAlpha,
      drawerSurfaceAlpha: drawerSurfaceAlpha ?? this.drawerSurfaceAlpha,
      infoDrawerSurfaceAlpha:
          infoDrawerSurfaceAlpha ?? this.infoDrawerSurfaceAlpha,
      hoverAlpha: hoverAlpha ?? this.hoverAlpha,
      primaryLabelAlpha: primaryLabelAlpha ?? this.primaryLabelAlpha,
      mutedLabelAlpha: mutedLabelAlpha ?? this.mutedLabelAlpha,
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
      darkSurfaceAlpha:
          lerpDouble(darkSurfaceAlpha, other.darkSurfaceAlpha, t)!,
      drawerSurfaceAlpha:
          lerpDouble(drawerSurfaceAlpha, other.drawerSurfaceAlpha, t)!,
      infoDrawerSurfaceAlpha:
          lerpDouble(infoDrawerSurfaceAlpha, other.infoDrawerSurfaceAlpha, t)!,
      hoverAlpha: lerpDouble(hoverAlpha, other.hoverAlpha, t)!,
      primaryLabelAlpha:
          lerpDouble(primaryLabelAlpha, other.primaryLabelAlpha, t)!,
      mutedLabelAlpha: lerpDouble(mutedLabelAlpha, other.mutedLabelAlpha, t)!,
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
