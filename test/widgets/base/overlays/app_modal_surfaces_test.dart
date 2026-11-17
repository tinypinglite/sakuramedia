import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';

import '../../../support/pump_with_providers.dart';

const _triggerKey = Key('modal-trigger');
const _dialogKey = Key('modal-dialog');
const _dialogContentKey = Key('modal-dialog-content');
const _dialogCloseKey = Key('modal-dialog-close');
const _stateProbeKey = Key('modal-state-probe');

void main() {
  testWidgets('desktop dialog closes from its shared close action', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      theme: sakuraDesktopThemeData,
      size: const Size(1100, 760),
      onPressed: (context) => showAppDialog<void>(
        context: context,
        builder: (_) => const AppDesktopDialog(
          dialogKey: _dialogKey,
          contentKey: _dialogContentKey,
          closeButtonKey: _dialogCloseKey,
          width: 320,
          child: SizedBox(height: 120),
        ),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.byKey(_dialogContentKey), findsOneWidget);

    await tester.tap(find.byKey(_dialogCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialogContentKey), findsNothing);
  });

  testWidgets('desktop dialog close transition finishes within 300ms', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      theme: sakuraDesktopThemeData,
      size: const Size(1100, 760),
      onPressed: (context) => showAppDialog<void>(
        context: context,
        builder: (_) => const AppDesktopDialog(
          dialogKey: _dialogKey,
          contentKey: _dialogContentKey,
          closeButtonKey: _dialogCloseKey,
          width: 320,
          child: SizedBox(height: 120),
        ),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_dialogCloseKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.byKey(_dialogContentKey), findsNothing);
  });

  testWidgets('bottom drawer keeps its content anchor', (tester) async {
    await _pumpHost(
      tester,
      theme: sakuraMobileThemeData,
      size: const Size(390, 844),
      onPressed: (context) => showAppBottomDrawer<void>(
        context: context,
        maxHeightFactor: 0.42,
        builder: (_) => const SizedBox(height: 120),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-bottom-drawer-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dialog keeps state through the dialog transition', (
    tester,
  ) async {
    var initCount = 0;
    await _pumpHost(
      tester,
      theme: sakuraDesktopThemeData,
      size: const Size(1100, 760),
      onPressed: (context) => showAppDialog<void>(
        context: context,
        builder: (_) => AppDesktopDialog(
          width: 320,
          child: _StateProbe(onInit: () => initCount++),
        ),
      ),
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_stateProbeKey), findsOneWidget);
    expect(initCount, 1);
  });

  testWidgets('glass filter popover opens, reports, and resets in footer', (
    tester,
  ) async {
    var opened = 0;
    var resets = 0;
    await _pumpGlassFilterPopover(
      tester,
      AppGlassFilterPopover(
        panelKey: const Key('glass-filter-panel'),
        triggerKey: const Key('glass-filter-trigger'),
        label: '全部',
        isDefault: false,
        onOpened: () => opened++,
        resetKey: const Key('glass-filter-reset'),
        onReset: () => resets++,
        panelBuilder: (_) =>
            const Text('筛选内容', key: Key('glass-filter-content')),
      ),
    );

    await tester.tap(find.byKey(const Key('glass-filter-trigger')));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.byKey(const Key('glass-filter-panel')), findsOneWidget);
    expect(find.byKey(const Key('glass-filter-content')), findsOneWidget);

    await tester.tap(find.byKey(const Key('glass-filter-reset')));
    await tester.pumpAndSettle();

    expect(resets, 1);
    expect(find.byKey(const Key('glass-filter-panel')), findsOneWidget);
  });

  testWidgets('glass filter popover scrolls and custom footer can close it', (
    tester,
  ) async {
    await _pumpGlassFilterPopover(
      tester,
      AppGlassFilterPopover(
        panelKey: const Key('scroll-filter-panel'),
        triggerKey: const Key('scroll-filter-trigger'),
        label: '筛选',
        scrollable: true,
        scrollViewKey: const Key('scroll-filter-view'),
        panelBuilder: (_) =>
            const SizedBox(key: Key('scroll-filter-content'), height: 1200),
        footerBuilder: (context, close) => TextButton(
          key: const Key('scroll-filter-close'),
          onPressed: close,
          child: const Text('关闭'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('scroll-filter-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scroll-filter-panel')), findsOneWidget);
    expect(find.byKey(const Key('scroll-filter-view')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('scroll-filter-view')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('scroll-filter-view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.tap(find.byKey(const Key('scroll-filter-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scroll-filter-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty glass filter content does not overflow', (tester) async {
    await _pumpGlassFilterPopover(
      tester,
      AppGlassFilterPopover(
        panelKey: const Key('empty-filter-panel'),
        triggerKey: const Key('empty-filter-trigger'),
        label: '筛选',
        panelBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    await tester.tap(find.byKey(const Key('empty-filter-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('empty-filter-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: _stateProbeKey, height: 80);
  }
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required ThemeData theme,
  required Size size,
  required void Function(BuildContext context) onPressed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: _triggerKey,
              onPressed: () => onPressed(context),
              child: const SizedBox(width: 32, height: 32),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpGlassFilterPopover(WidgetTester tester, Widget popover) {
  return pumpWithProviders(
    tester,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: AppGlassListHeader(leading: popover),
        ),
      ),
    ),
    theme: buildSakuraDesktopThemeData(),
    physicalSize: const Size(1100, 760),
  );
}
