import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

void main() {
  setUpAll(() async {
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  });

  Widget buildSurface({
    AppGlassTone tone = AppGlassTone.control,
    bool blur = true,
    bool highContrast = false,
    double? width,
    double? height,
  }) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: Scaffold(
          body: Center(
            child: AppGlassSurface(
              tone: tone,
              blur: blur,
              width: width,
              height: height,
              child: const SizedBox(
                key: Key('glass-child'),
                width: 60,
                height: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('builds every tone with the liquid glass engine', (
    WidgetTester tester,
  ) async {
    for (final tone in AppGlassTone.values) {
      await tester.pumpWidget(buildSurface(tone: tone));

      expect(find.byType(AppGlassSurface), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sidebar glass does not opt into elevation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSurface(tone: AppGlassTone.sidebar));

    final container = tester.widget<GlassContainer>(
      find.byType(GlassContainer),
    );
    expect(container.allowElevation, isFalse);
    expect(container.settings?.shadowElevation, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blur false uses the fallback surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSurface(blur: false));

    expect(find.byKey(const Key('app-glass-fallback')), findsOneWidget);
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves requested width and height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSurface(width: 120, height: 40));

    final rect = tester.getRect(find.byType(AppGlassSurface));
    expect(rect.width, 120);
    expect(rect.height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast uses the fallback surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSurface(highContrast: true));

    expect(find.byKey(const Key('app-glass-fallback')), findsOneWidget);
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-only radius uses the asymmetric glass path', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Center(
            child: AppGlassSurface(
              tone: AppGlassTone.overlay,
              width: 200,
              height: 120,
              borderRadius: BorderRadius.horizontal(
                left: const Radius.circular(18),
              ),
              child: const SizedBox(
                key: Key('glass-child'),
                width: 160,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GlassContainer), findsOneWidget);
    expect(tester.getSize(find.byType(AppGlassSurface)), const Size(200, 120));
    expect(tester.takeException(), isNull);
  });
}
