import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/use_multi_selection.dart';

void main() {
  testWidgets('useMultiSelection 管理选择模式与单个 id', (tester) async {
    late MultiSelection<int> selection;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            selection = useMultiSelection<int>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(selection.selectionMode, isFalse);
    expect(selection.selectedCount, 0);
    expect(selection.isAllSelected(const <int>[]), isFalse);

    selection.enter(7);
    await tester.pump();
    expect(selection.selectionMode, isTrue);
    expect(selection.selectedIds, <int>{7});

    selection.toggle(8);
    selection.toggle(7);
    await tester.pump();
    expect(selection.selectedIds, <int>{8});

    selection.exit();
    await tester.pump();
    expect(selection.selectionMode, isFalse);
    expect(selection.selectedCount, 0);
  });

  testWidgets('useMultiSelection 的全选切换保留范围外选中项', (tester) async {
    late MultiSelection<int> selection;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            selection = useMultiSelection<int>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    selection.toggle(1);
    selection.toggleAll(const <int>[1, 2, 3]);
    await tester.pump();
    expect(selection.selectedIds, <int>{1, 2, 3});
    expect(selection.isAllSelected(const <int>[1, 2, 3]), isTrue);

    selection.toggleAll(const <int>[1, 2, 3]);
    await tester.pump();
    expect(selection.selectedIds, isEmpty);

    selection.toggle(9);
    selection.toggleAll(const <int>[2, 3]);
    selection.toggleAll(const <int>[2, 3]);
    await tester.pump();
    expect(selection.selectedIds, <int>{9});
  });
}
