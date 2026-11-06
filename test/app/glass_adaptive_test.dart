import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/glass_quality_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';

void main() {
  testWidgets('MyApp installs one root adaptive glass scope', (tester) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    final qualityStore = InMemoryGlassQualityStore(GlassQuality.standard);

    await tester.pumpWidget(
      MyApp(
        platformOverride: AppPlatform.mobile,
        sessionStore: sessionStore,
        glassQualityStore: qualityStore,
      ),
    );
    await tester.pump();

    expect(find.byType(GlassAdaptiveScope), findsOneWidget);

    final scope = tester.widget<GlassAdaptiveScope>(
      find.byType(GlassAdaptiveScope),
    );
    expect(scope.initialQuality, GlassQuality.standard);
    expect(scope.minQuality, GlassQuality.minimal);
    expect(scope.maxQuality, GlassQuality.premium);
    expect(scope.targetFrameMs, 16);
    expect(scope.allowStepUp, isTrue);
    expect(scope.frostStep, isFalse);
    expect(tester.takeException(), isNull);
  });
}
