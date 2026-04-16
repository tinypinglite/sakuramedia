import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

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
      inlineIconPadding = 5;

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
    );
  }

  @override
  AppLayoutTokens lerp(ThemeExtension<AppLayoutTokens>? other, double t) {
    if (other is! AppLayoutTokens) {
      return this;
    }
    return AppLayoutTokens(
      inlineActionButtonSize:
          lerpDouble(
            inlineActionButtonSize,
            other.inlineActionButtonSize,
            t,
          )!,
      panelIconContainerSize:
          lerpDouble(
            panelIconContainerSize,
            other.panelIconContainerSize,
            t,
          )!,
      segmentedControlHeight:
          lerpDouble(segmentedControlHeight, other.segmentedControlHeight, t)!,
      filterFieldWidthSm:
          lerpDouble(filterFieldWidthSm, other.filterFieldWidthSm, t)!,
      filterFieldWidthMd:
          lerpDouble(filterFieldWidthMd, other.filterFieldWidthMd, t)!,
      filterFieldWidthLg:
          lerpDouble(filterFieldWidthLg, other.filterFieldWidthLg, t)!,
      filterFieldWidthXl:
          lerpDouble(filterFieldWidthXl, other.filterFieldWidthXl, t)!,
      dialogWidthSm: lerpDouble(dialogWidthSm, other.dialogWidthSm, t)!,
      dialogWidthMd: lerpDouble(dialogWidthMd, other.dialogWidthMd, t)!,
      dialogInsetPadding:
          lerpDouble(dialogInsetPadding, other.dialogInsetPadding, t)!,
      emptySectionVerticalPadding:
          lerpDouble(
            emptySectionVerticalPadding,
            other.emptySectionVerticalPadding,
            t,
          )!,
      inlineIconPadding:
          lerpDouble(inlineIconPadding, other.inlineIconPadding, t)!,
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
