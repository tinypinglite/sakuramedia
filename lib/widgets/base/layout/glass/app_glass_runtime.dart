import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

abstract final class AppGlassRuntime {
  static Future<void> initialize() => LiquidGlassWidgets.initialize();

  static Widget wrap({
    required Widget child,
    Brightness? Function(BuildContext)? brightnessResolver,
  }) {
    return LiquidGlassWidgets.wrap(
      brightnessResolver: brightnessResolver,
      child: child,
    );
  }
}
