import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_speed_button.dart';

void main() {
  group('MoviePlayerSpeedButton', () {
    testWidgets('shows 倍速 before any explicit selection', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);

      expect(find.text('倍速'), findsOneWidget);
      expect(find.text('1.0x'), findsNothing);
    });

    testWidgets('shows menu on hover', (WidgetTester tester) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );

      expect(find.byKey(const Key('movie-player-speed-menu')), findsOneWidget);
    });

    testWidgets('toggles menu on tap', (WidgetTester tester) async {
      await _pumpHarness(tester);

      await tester.tap(find.byKey(const Key('movie-player-speed-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-player-speed-menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie-player-speed-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-player-speed-menu')), findsNothing);
    });

    testWidgets('closes menu when tapping outside', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);

      await tester.tap(find.byKey(const Key('movie-player-speed-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-player-speed-menu')), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-player-speed-menu')), findsNothing);
    });

    testWidgets('keeps menu open when pointer moves from button to menu', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );
      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-menu')),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.byKey(const Key('movie-player-speed-menu')), findsOneWidget);
    });

    testWidgets('closes menu after pointer leaves button and menu region', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );
      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-menu')),
      );
      final buttonRegion = tester.widget<MouseRegion>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-speed-button')),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      final menuRegion = tester.widget<MouseRegion>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-speed-menu')),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      buttonRegion.onExit?.call(const PointerExitEvent(position: Offset.zero));
      menuRegion.onExit?.call(const PointerExitEvent(position: Offset.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('movie-player-speed-menu')), findsNothing);
    });

    testWidgets('marks current rate with a check icon and dedicated slot', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );

      expect(
        find.byKey(const Key('movie-player-speed-menu-item-check-1_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-player-speed-menu-item-check-slot-1_5')),
        findsOneWidget,
      );
    });

    testWidgets('selects a rate on click and updates button text', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );
      final itemGestureDetector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-speed-menu-item-1_5')),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      itemGestureDetector.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.text('1.5x'), findsOneWidget);
      expect(find.byKey(const Key('movie-player-speed-menu')), findsNothing);
    });

    testWidgets('treats selecting 1.0x as an explicit selection', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);
      final gesture = await _createMouseGesture(tester);

      await _moveMouseToFinder(
        tester,
        gesture,
        find.byKey(const Key('movie-player-speed-button')),
      );
      final itemGestureDetector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.byKey(const Key('movie-player-speed-menu-item-1_0')),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      itemGestureDetector.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('倍速'), findsNothing);
    });

    testWidgets('uses overlay tokens for menu width and label font size', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(tester);

      await tester.tap(find.byKey(const Key('movie-player-speed-button')));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(
        find.byKey(const Key('movie-player-speed-menu')),
      );
      final label = tester.widget<Text>(
        find.byKey(const Key('movie-player-speed-menu-item-label-1_0')),
      );

      expect(menuRect.width, sakuraThemeData.appOverlayTokens.menuWidthSm);
      expect(label.style?.fontSize, sakuraThemeData.appTextScale.s14);
    });
  });
}

Future<void> _pumpHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 96),
            child: _MoviePlayerSpeedButtonHarness(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MoviePlayerSpeedButtonHarness extends StatefulWidget {
  const _MoviePlayerSpeedButtonHarness();

  @override
  State<_MoviePlayerSpeedButtonHarness> createState() =>
      _MoviePlayerSpeedButtonHarnessState();
}

class _MoviePlayerSpeedButtonHarnessState
    extends State<_MoviePlayerSpeedButtonHarness> {
  double _currentRate = 1.0;
  bool _hasExplicitSelection = false;

  @override
  Widget build(BuildContext context) {
    return MoviePlayerSpeedButton(
      currentRate: _currentRate,
      hasExplicitSelection: _hasExplicitSelection,
      onRateSelected: (rate) async {
        setState(() {
          _currentRate = rate;
          _hasExplicitSelection = true;
        });
      },
    );
  }
}

Future<TestGesture> _createMouseGesture(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

Future<void> _moveMouseToFinder(
  WidgetTester tester,
  TestGesture gesture,
  Finder finder,
) async {
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
}
