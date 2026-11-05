import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_ambient_backdrop.dart';

void main() {
  testWidgets('renders themed ambient layers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: DesktopAmbientBackdrop()),
      ),
    );

    expect(find.byKey(const Key('desktop-ambient-backdrop')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to an opaque canvas in high contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Scaffold(body: DesktopAmbientBackdrop()),
        ),
      ),
    );

    final fallback = tester.widget<ColoredBox>(
      find.byKey(const Key('desktop-ambient-backdrop')),
    );
    expect(fallback.color, sakuraThemeData.appColors.surfacePage);
  });
}
