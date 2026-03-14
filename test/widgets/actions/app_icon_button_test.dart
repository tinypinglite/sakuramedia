import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';

void main() {
  testWidgets('app icon button uses md icon token by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppIconButton(icon: Icon(Icons.search_rounded)),
        ),
      ),
    );

    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.search_rounded),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(iconTheme.data.size, AppComponentTokens.defaults().iconSizeMd);
  });

  testWidgets('app icon button wraps tooltip when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppIconButton(tooltip: '搜索', icon: Icon(Icons.search_rounded)),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, '搜索');
  });

  testWidgets('app icon button uses transparent unselected surface colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppIconButton(icon: Icon(Icons.public_rounded)),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.public_rounded),
            matching: find.byType(IconTheme),
          )
          .first,
    );

    expect(material.color, Colors.transparent);
    expect(shape.side.color, Colors.transparent);
    expect(iconTheme.data.color, AppColors.defaults().textMuted);
  });

  testWidgets('app icon button uses selected surface colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppIconButton(
            isSelected: true,
            icon: Icon(Icons.public_rounded),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.public_rounded),
            matching: find.byType(IconTheme),
          )
          .first,
    );

    expect(material.color, AppColors.defaults().surfaceCard);
    expect(shape.side.color, AppColors.defaults().borderStrong);
    expect(iconTheme.data.color, AppColors.defaults().textPrimary);
  });

  testWidgets('app icon button is disabled when onPressed is null', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppIconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppIconButton));
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('app icon button regular size expands tap target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Wrap(
            children: const [
              AppIconButton(
                key: Key('compact-button'),
                icon: Icon(Icons.search_rounded),
              ),
              AppIconButton(
                key: Key('regular-button'),
                size: AppIconButtonSize.regular,
                icon: Icon(Icons.search_rounded),
              ),
            ],
          ),
        ),
      ),
    );

    final compactBox = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(AppIconButton).at(0),
            matching: find.byType(SizedBox),
          ),
        )
        .firstWhere((box) => box.width != null && box.height != null);
    final regularBox = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(AppIconButton).at(1),
            matching: find.byType(SizedBox),
          ),
        )
        .firstWhere((box) => box.width != null && box.height != null);

    expect(regularBox.width!, greaterThan(compactBox.width!));
    expect(regularBox.height!, greaterThan(compactBox.height!));
  });
}
