import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

void main() {
  testWidgets('bottom form shows the scroll cue in a drawer shell', (
    tester,
  ) async {
    await _pumpForm(tester, isDrawer: true);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(
      find.byKey(const Key('app-bottom-drawer-scroll-cue')),
      findsOneWidget,
    );
  });

  testWidgets('bottom form hides the scroll cue in a desktop dialog shell', (
    tester,
  ) async {
    await _pumpForm(tester, isDrawer: false);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(find.byKey(const Key('app-bottom-drawer-scroll-cue')), findsNothing);
  });

  testWidgets('direct bottom drawer form keeps the scroll cue', (tester) async {
    await _pumpForm(tester);

    expect(
      find.byKey(const Key('app-bottom-drawer-scroll-cue')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpForm(WidgetTester tester, {bool? isDrawer}) async {
  final form = SizedBox(
    width: 320,
    height: 320,
    child: AppBottomFormSheet(
      formKey: GlobalKey<FormState>(),
      title: '编辑表单',
      body: Column(
        children: [
          for (var index = 0; index < 12; index++)
            SizedBox(height: 52, child: Text('表单项 $index')),
        ],
      ),
      submitKey: const Key('bottom-form-submit'),
      isSubmitting: false,
      onSubmit: () {},
    ),
  );
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
          child: isDrawer == null
              ? form
              : AppAdaptiveModalShellScope(isDrawer: isDrawer, child: form),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
