import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/routes/desktop_branch_cache.dart';

void main() {
  testWidgets('retains only the eight most recently visited branches', (
    tester,
  ) async {
    final children = List<Widget>.generate(
      9,
      (index) => Text('page$index', key: ValueKey<int>(index)),
    );

    Widget buildCache(int currentIndex) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: DesktopBranchCache(
          currentIndex: currentIndex,
          children: children,
        ),
      );
    }

    await tester.pumpWidget(buildCache(0));
    for (var index = 1; index < children.length; index += 1) {
      await tester.pumpWidget(buildCache(index));
    }

    expect(find.text('page0', skipOffstage: false), findsNothing);
    for (var index = 1; index < children.length; index += 1) {
      expect(find.text('page$index', skipOffstage: false), findsOneWidget);
    }
    expect(find.text('page8'), findsOneWidget);
  });
}
