import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';

void main() {
  group('SelectionState', () {
    test(
      'toggle activates selection, tracks anchor and removes on second tap',
      () {
        var state = SelectionState<int>().activate().toggle(2);

        expect(state.active, isTrue);
        expect(state.selected, {2});
        expect(state.anchor, 2);

        state = state.toggle(2);
        expect(state.active, isTrue);
        expect(state.selected, isEmpty);
        expect(state.anchor, isNull);
      },
    );

    test('range selection is inclusive, additive and does not move anchor', () {
      final state = SelectionState<int>(
        active: true,
        selected: {1},
        anchor: 2,
      ).extendTo(5, [1, 2, 3, 4, 5, 6]);

      expect(state.selected, {1, 2, 3, 4, 5});
      expect(state.anchor, 2);
    });

    test('range selection works backwards', () {
      final state = SelectionState<int>(
        active: true,
        selected: {5},
        anchor: 5,
      ).extendTo(2, [1, 2, 3, 4, 5]);

      expect(state.selected, {2, 3, 4, 5});
      expect(state.anchor, 5);
    });

    test('range falls back to selecting target when anchor is missing', () {
      final state = SelectionState<int>(
        active: true,
        selected: {4},
      ).extendTo(2, [1, 2, 3, 4]);

      expect(state.selected, {2, 4});
      expect(state.anchor, 2);
    });

    test('toggleAll adds and then removes the same ids', () {
      var state = SelectionState<int>().toggleAll([1, 2, 3]);
      expect(state.active, isTrue);
      expect(state.selected, {1, 2, 3});

      state = state.toggleAll([1, 2, 3]);
      expect(state.selected, isEmpty);
      expect(state.active, isTrue);
    });

    test('policy can reject additions but never rejects removals', () {
      const policy = SelectionPolicy<int>(canSelect: _keepAtLeastOne);
      var state = SelectionState<int>(
        active: true,
        selected: {1, 2},
      ).toggle(3, policy: policy);
      expect(state.selected, {1, 2});

      state = state.toggle(2, policy: policy);
      expect(state.selected, {1});
    });

    test('range applies policy to every addition', () {
      const policy = SelectionPolicy<int>(canSelect: _atMostTwo);
      final state = SelectionState<int>(
        active: true,
        anchor: 1,
      ).extendTo(4, [1, 2, 3, 4], policy: policy);

      expect(state.selected, {1, 2});
    });

    test('clear keeps selection mode, deactivate clears everything', () {
      final active = SelectionState<int>(
        active: true,
        selected: {1, 2},
        anchor: 2,
      );

      final cleared = active.clear();
      expect(cleared.active, isTrue);
      expect(cleared.selected, isEmpty);
      expect(cleared.anchor, isNull);

      final inactive = active.deactivate();
      expect(inactive.active, isFalse);
      expect(inactive.selected, isEmpty);
      expect(inactive.anchor, isNull);
    });

    test('retainOnly removes missing ids and clears stale anchor', () {
      final state = SelectionState<int>(
        active: true,
        selected: {1, 2, 3},
        anchor: 2,
      ).retainOnly([1, 3]);

      expect(state.selected, {1, 3});
      expect(state.anchor, isNull);
      expect(state.active, isTrue);
    });

    test('gesture applies toggle, range and plain semantics', () {
      final ordered = [1, 2, 3, 4];
      var state = SelectionState<int>().applyGesture(
        2,
        SelectionGesture.toggle,
        ordered,
      );
      expect(state.active, isTrue);
      expect(state.selected, {2});

      state = state.applyGesture(4, SelectionGesture.range, ordered);
      expect(state.selected, {2, 3, 4});

      state = state.applyGesture(3, SelectionGesture.plain, ordered);
      expect(state.selected, {2, 4});
    });
  });

  group('SelectionController', () {
    test(
      'tap handler toggles in selection mode and runs normal tap otherwise',
      () {
        var normalTaps = 0;
        final controller = SelectionController<int>(
          orderedIds: () => const [1, 2, 3],
        );
        final tap = controller.tapHandler(2, () => normalTaps += 1);

        tap();
        expect(normalTaps, 1);
        expect(controller.active, isFalse);

        controller.enterSelection();
        tap();
        expect(normalTaps, 1);
        expect(controller.selectedIds, {2});
      },
    );

    test('long press enters selection and selects the item', () {
      final controller = SelectionController<int>(
        orderedIds: () => const [1, 2, 3],
      );

      controller.longPressHandler(3)();

      expect(controller.active, isTrue);
      expect(controller.selectedIds, {3});
      expect(controller.state.anchor, 3);
    });

    test('removeAll and replaceSelected keep selection mode', () {
      final controller = SelectionController<int>(
        orderedIds: () => const [1, 2, 3],
      );
      controller.enterSelection();
      controller.toggleSelect(1);
      controller.toggleSelect(2);
      controller.removeAll([1]);
      expect(controller.selectedIds, {2});
      expect(controller.active, isTrue);

      controller.replaceSelected([3]);
      expect(controller.selectedIds, {3});
      expect(controller.active, isTrue);
    });
  });

  testWidgets('resolves Shift and primary modifier on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      expect(resolveSelectionGesture(), SelectionGesture.plain);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(resolveSelectionGesture(), SelectionGesture.range);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      expect(resolveSelectionGesture(), SelectionGesture.toggle);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('resolves Ctrl on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      expect(resolveSelectionGesture(), SelectionGesture.toggle);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('selectedChangedHandler honors Shift range', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final controller = SelectionController<int>(
      orderedIds: () => const [1, 2, 3],
    );
    try {
      controller.enterSelection(initial: 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      controller.selectedChangedHandler(3)(true);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(controller.selectedIds, {1, 2, 3});
    } finally {
      controller.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

bool _keepAtLeastOne(int id, Set<int> selected) {
  if (selected.contains(id)) return true;
  return selected.length < 2;
}

bool _atMostTwo(int id, Set<int> selected) => selected.length < 2;
