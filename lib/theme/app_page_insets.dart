import 'package:flutter/material.dart';

@immutable
class AppPageInsets {
  const AppPageInsets._();

  static const double desktop = 24;
  static const double compact = 16;

  static const EdgeInsets zero = EdgeInsets.zero;
  static const EdgeInsets desktopStandard = EdgeInsets.all(desktop);
  static const EdgeInsets compactStandard = EdgeInsets.all(compact);
}
