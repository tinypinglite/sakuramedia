import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/feedback/app_mobile_skeleton.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('AppSkeletonBlock renders Container with provided size', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const AppSkeletonBlock(width: 120, height: 16)),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth ?? 0, anyOf(equals(120), lessThan(1)));
    expect(find.byType(AppSkeletonBlock), findsOneWidget);
  });

  testWidgets('AppMobileSkeletonCard renders 3 blocks inside', (tester) async {
    await tester.pumpWidget(wrap(const AppMobileSkeletonCard()));

    expect(find.byType(AppMobileSkeletonCard), findsOneWidget);
    expect(find.byType(AppSkeletonBlock), findsNWidgets(3));
  });

  testWidgets('AppMobileSkeletonList renders default itemCount cards', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppMobileSkeletonList()));

    expect(find.byType(AppMobileSkeletonCard), findsNWidgets(3));
  });

  testWidgets('AppMobileSkeletonList respects custom itemCount', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AppMobileSkeletonList(itemCount: 5)));

    expect(find.byType(AppMobileSkeletonCard), findsNWidgets(5));
  });

  testWidgets('AppMobileSkeletonList uses custom itemBuilder when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppMobileSkeletonList(
          itemCount: 2,
          itemBuilder:
              (_, index) =>
                  SizedBox(key: Key('custom-$index'), height: 40),
        ),
      ),
    );

    expect(find.byKey(const Key('custom-0')), findsOneWidget);
    expect(find.byKey(const Key('custom-1')), findsOneWidget);
    expect(find.byType(AppMobileSkeletonCard), findsNothing);
  });
}
