import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer_scroll_region.dart';

const _cueKey = Key('app-bottom-drawer-scroll-cue');
const _footerKey = Key('scroll-region-footer');

void main() {
  testWidgets('short content does not render the scroll cue', (tester) async {
    await _pumpRegion(tester, itemCount: 2);

    expect(find.byKey(_cueKey), findsNothing);
  });

  testWidgets('overflowing content shows a cue that scrolls to the end', (
    tester,
  ) async {
    await _pumpRegion(tester, itemCount: 20);

    expect(find.byKey(_cueKey), findsOneWidget);
    final cueRect = tester.getRect(find.byKey(_cueKey));
    final footerRect = tester.getRect(find.byKey(_footerKey));
    expect(cueRect.bottom, lessThanOrEqualTo(footerRect.top));

    await _tapCueUntilGone(tester);

    expect(find.byKey(_cueKey), findsNothing);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
  });

  testWidgets('scrolling back up makes the cue visible again', (tester) async {
    await _pumpRegion(tester, itemCount: 20);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_cueKey), findsOneWidget);

    await _tapCueUntilGone(tester);
    expect(find.byKey(_cueKey), findsNothing);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(_cueKey), findsOneWidget);
  });

  testWidgets('lazy list overflow is detected after first layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraDesktopThemeData,
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: AppBottomDrawerScrollRegion(
              builder: (context, controller) => ListView.builder(
                controller: controller,
                itemCount: 20,
                itemBuilder: (context, index) =>
                    SizedBox(height: 48, child: Text('列表项 $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_cueKey), findsOneWidget);
  });
}

Future<void> _pumpRegion(WidgetTester tester, {required int itemCount}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      theme: sakuraDesktopThemeData,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 360,
            child: Column(
              children: [
                Flexible(
                  child: AppBottomDrawerScrollRegion(
                    builder: (context, controller) => SingleChildScrollView(
                      controller: controller,
                      child: Column(
                        children: [
                          for (var index = 0; index < itemCount; index++)
                            SizedBox(
                              height: 60,
                              child: Center(child: Text('项目 $index')),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  key: _footerKey,
                  height: 48,
                  child: Center(child: Text('固定底栏')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapCueUntilGone(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    if (find.byKey(_cueKey).evaluate().isEmpty) {
      return;
    }
    await tester.tap(find.byKey(_cueKey));
    await tester.pumpAndSettle();
  }
}
