import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sakuramedia/app/glass_performance.dart';

void main() {
  test('adaptive config keeps the package defaults and one kill switch', () {
    expect(AppGlassPerformance.enabled, isTrue);

    final config = AppGlassPerformance.adaptiveConfig(
      initialQuality: GlassQuality.standard,
      onQualityChanged: (_) {},
    );

    expect(config.initialQuality, GlassQuality.standard);
    expect(config.minQuality, GlassQuality.minimal);
    expect(config.maxQuality, GlassQuality.premium);
    expect(config.targetFrameMs, 16);
    expect(config.warmupPremiumThresholdMs, 20);
    expect(config.warmupStandardThresholdMs, 28);
    expect(config.allowStepUp, isTrue);
    expect(config.frostStep, isFalse);
    expect(config.onDiagnostic, isNotNull);
  });
}
