import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';

void main() {
  List<DropdownMenuItem<int>> buildItems(int count) {
    return List<DropdownMenuItem<int>>.generate(
      count,
      (index) =>
          DropdownMenuItem<int>(value: index, child: Text('Item $index')),
    );
  }

  Finder findTriggerSurface() {
    return find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
        return false;
      }
      final decoration = widget.decoration as BoxDecoration;
      return decoration.borderRadius == sakuraThemeData.appRadius.smBorder &&
          decoration.color == sakuraThemeData.appColors.surfaceMuted &&
          (decoration.boxShadow?.isEmpty ?? true) &&
          decoration.border != null;
    });
  }

  Finder findMenuSurface() {
    return find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
        return false;
      }
      final decoration = widget.decoration as BoxDecoration;
      return decoration.borderRadius == sakuraThemeData.appRadius.smBorder &&
          decoration.color == sakuraThemeData.appColors.surfaceCard &&
          (decoration.boxShadow?.isNotEmpty ?? false) &&
          decoration.border != null;
    });
  }

  Widget wrapApp(Widget child, {double width = 420, double height = 320}) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('renders label placeholder and selected value styles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            label: '目标媒体库',
            value: 1,
            items: const [DropdownMenuItem<int>(value: 1, child: Text('默认'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('目标媒体库'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);

    final selectedStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('默认'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(selectedStyle.style.color, sakuraThemeData.appColors.textPrimary);

    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            label: '目标媒体库',
            items: const [DropdownMenuItem<int>(value: 1, child: Text('默认'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请选择'), findsOneWidget);
    final placeholderStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('请选择'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(placeholderStyle.style.color, sakuraThemeData.appColors.textMuted);
  });

  testWidgets('supports compact trigger height for action rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            size: AppSelectFieldSize.compact,
            value: 1,
            items: const [DropdownMenuItem<int>(value: 1, child: Text('默认'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final triggerRect = tester.getRect(findTriggerSurface());
    expect(triggerRect.height, moreOrLessEquals(36, epsilon: 0.1));
  });

  testWidgets('applies custom text style to trigger and menu items', (
    WidgetTester tester,
  ) async {
    const customTextStyle = TextStyle(fontSize: 13);

    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            value: 1,
            textStyle: customTextStyle,
            items: const [
              DropdownMenuItem<int>(value: 1, child: Text('默认')),
              DropdownMenuItem<int>(value: 2, child: Text('归档')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final triggerStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.descendant(
              of: findTriggerSurface(),
              matching: find.text('默认'),
            ),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(triggerStyle.style.fontSize, 13);

    await tester.tap(find.text('默认'));
    await tester.pumpAndSettle();

    final menuStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.descendant(
              of: findMenuSurface(),
              matching: find.text('归档'),
            ),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(menuStyle.style.fontSize, 13);
  });

  testWidgets('opens menu selects item and closes on outside tap', (
    WidgetTester tester,
  ) async {
    int? selectedValue;

    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            label: '目标媒体库',
            items: const [
              DropdownMenuItem<int>(value: 1, child: Text('默认')),
              DropdownMenuItem<int>(value: 2, child: Text('归档')),
            ],
            onChanged: (value) => selectedValue = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();

    expect(find.text('默认'), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);

    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(selectedValue, 2);
    expect(findMenuSurface(), findsNothing);

    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();
    expect(findMenuSurface(), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(findMenuSurface(), findsNothing);
  });

  testWidgets('can switch from non-null option back to null option', (
    WidgetTester tester,
  ) async {
    String? selectedValue = 'reminder';

    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<String?>(
            value: selectedValue,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('全部分类')),
              DropdownMenuItem<String?>(value: 'result', child: Text('结果')),
              DropdownMenuItem<String?>(value: 'reminder', child: Text('提醒')),
            ],
            onChanged: (value) => selectedValue = value,
          ),
        ),
      ),
    );

    expect(find.text('提醒'), findsOneWidget);

    await tester.tap(find.text('提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部分类').last);
    await tester.pumpAndSettle();

    expect(selectedValue, isNull);
    expect(find.text('全部分类'), findsOneWidget);

    await tester.tap(find.text('全部分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结果').last);
    await tester.pumpAndSettle();

    expect(selectedValue, 'result');
    expect(find.text('结果'), findsOneWidget);
  });

  testWidgets('aligns menu width and keeps menu close to trigger', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            label: '目标媒体库',
            items: const [DropdownMenuItem<int>(value: 1, child: Text('默认'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final triggerRectBeforeOpen = tester.getRect(findTriggerSurface());

    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();

    final triggerRect = tester.getRect(findTriggerSurface());
    final menuRect = tester.getRect(findMenuSurface());

    expect(triggerRect, triggerRectBeforeOpen);
    expect(menuRect.width, moreOrLessEquals(triggerRect.width, epsilon: 0.1));
    expect(menuRect.top - triggerRect.bottom, inInclusiveRange(4.0, 8.0));
  });

  testWidgets('opens upward when there is not enough space below', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 150),
              Center(
                child: SizedBox(
                  width: 320,
                  child: AppSelectField<int>(
                    label: '目标媒体库',
                    items: buildItems(6),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();

    final triggerRect = tester.getRect(findTriggerSurface());
    final menuRect = tester.getRect(findMenuSurface());

    expect(triggerRect.top - menuRect.bottom, inInclusiveRange(4.0, 8.0));
  });

  testWidgets('caps menu height and supports scrolling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        SizedBox(
          width: 320,
          child: AppSelectField<int>(
            label: '目标媒体库',
            items: buildItems(20),
            onChanged: (_) {},
          ),
        ),
        height: 420,
      ),
    );

    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();

    final menuRect = tester.getRect(findMenuSurface());
    expect(menuRect.height, lessThanOrEqualTo(244));
    expect(
      tester.getRect(find.text('Item 19')).top,
      greaterThan(menuRect.bottom),
    );

    await tester.dragUntilVisible(
      find.text('Item 19'),
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Item 19')).bottom,
      lessThanOrEqualTo(menuRect.bottom),
    );
  });

  testWidgets('shows error state and prevents opening when disabled', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      wrapApp(
        Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.always,
          child: SizedBox(
            width: 320,
            child: AppSelectField<int>(
              label: '目标媒体库',
              items: const [DropdownMenuItem<int>(value: 1, child: Text('默认'))],
              onChanged: null,
              validator: (value) => value == null ? '请选择目标媒体库' : null,
            ),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pumpAndSettle();

    expect(find.text('请选择目标媒体库'), findsOneWidget);

    final decoration =
        tester.widget<DecoratedBox>(findTriggerSurface()).decoration
            as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, sakuraThemeData.colorScheme.error);

    await tester.tap(find.text('请选择'));
    await tester.pumpAndSettle();

    expect(findMenuSurface(), findsNothing);
  });
}
