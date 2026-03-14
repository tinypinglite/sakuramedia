import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('image action menu appears near pointer in a standard scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _MenuTestTrigger())),
    );

    final trigger = find.byKey(const Key('menu-test-trigger'));
    final pointer = tester.getCenter(trigger);

    await tester.tapAt(pointer, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    final menuTopLeft = tester.getTopLeft(_popupMenuFinder());
    expect((menuTopLeft - pointer).distance, lessThan(48));
  });

  testWidgets(
    'image action menu appears near pointer inside an offset navigator',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _OffsetNavigatorHost(child: _MenuTestPage())),
      );

      final trigger = find.byKey(const Key('menu-test-trigger'));
      final pointer = tester.getCenter(trigger);

      await tester.tapAt(pointer, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      final menuTopLeft = tester.getTopLeft(_popupMenuFinder());
      expect((menuTopLeft - pointer).distance, lessThan(48));
    },
  );

  testWidgets('image action menu supports long press positioning', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: _OffsetNavigatorHost(child: _MenuTestPage())),
    );

    final trigger = find.byKey(const Key('menu-test-trigger'));
    final pointer = tester.getCenter(trigger);
    final gesture = await tester.startGesture(pointer);
    await tester.pump(kLongPressTimeout);
    await gesture.up();
    await tester.pumpAndSettle();

    final menuTopLeft = tester.getTopLeft(_popupMenuFinder());
    expect((menuTopLeft - pointer).distance, lessThan(48));
  });
}

Finder _popupMenuFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget.runtimeType.toString() == '_PopupMenu<AppImageActionType>',
  );
}

class _OffsetNavigatorHost extends StatelessWidget {
  const _OffsetNavigatorHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 180, top: 120),
          child: SizedBox(
            width: 420,
            height: 320,
            child: Navigator(
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(builder: (context) => child),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTestPage extends StatelessWidget {
  const _MenuTestPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: _MenuTestTrigger()));
  }
}

class _MenuTestTrigger extends StatelessWidget {
  const _MenuTestTrigger();

  @override
  Widget build(BuildContext context) {
    return AppImageActionTrigger(
      onRequestMenu:
          (globalPosition) => showAppImageActionMenu(
            context: context,
            actions: const [
              AppImageActionDescriptor(
                type: AppImageActionType.searchSimilar,
                label: '相似图片',
                icon: Icons.image_search_outlined,
              ),
            ],
            globalPosition: globalPosition,
          ),
      child: Container(
        key: const Key('menu-test-trigger'),
        width: 120,
        height: 120,
        color: Colors.blueGrey,
      ),
    );
  }
}
