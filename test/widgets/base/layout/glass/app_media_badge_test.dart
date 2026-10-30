import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_media_badge.dart';

void main() {
  testWidgets('renders label and leading on a borderless smoked surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppMediaBadge(
            label: '42',
            leading: Icon(Icons.local_fire_department_rounded),
          ),
        ),
      ),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppMediaBadge),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.border, isNull);
  });

  testWidgets('fixed width and height include the whole surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppMediaBadge(label: '4K', width: 48, height: 24),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AppMediaBadge));
    expect(size.width, 48);
    expect(size.height, 24);
  });

  testWidgets('fixed-size prominent label is not ellipsized', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppMediaBadge(
            label: '4K',
            width: 32,
            height: 24,
            padding: EdgeInsets.zero,
            size: AppMediaBadgeSize.prominent,
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text('4K'));
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
