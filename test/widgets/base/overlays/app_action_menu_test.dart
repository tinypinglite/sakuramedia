import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_context_menu_trigger.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

const _triggerKey = Key('action-menu-trigger');
const _contextTargetKey = Key('action-menu-context-target');
const _editKey = Key('action-menu-edit');
const _hiddenKey = Key('action-menu-hidden');
const _disabledKey = Key('action-menu-disabled');
const _deleteKey = Key('action-menu-delete');

void main() {
  testWidgets('锚定菜单过滤隐藏项并返回选中值', (tester) async {
    Future<String?>? result;
    await _pumpHost(
      tester,
      onPressed: (context) {
        result = showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: <AppMenuItem<String>>[
            const AppMenuItem(
              key: _editKey,
              value: 'edit',
              label: '编辑',
              subtitle: '编辑当前项目',
              icon: Icons.edit_outlined,
            ),
            const AppMenuItem(
              key: _hiddenKey,
              value: 'hidden',
              label: '隐藏项',
              visible: false,
            ),
            const AppMenuItem(
              key: _deleteKey,
              value: 'delete',
              label: '删除',
              icon: Icons.delete_outline_rounded,
              tone: AppTextTone.error,
            ),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_editKey), findsOneWidget);
    expect(find.byKey(_hiddenKey), findsNothing);
    expect(find.byKey(_deleteKey), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_editKey));
    await tester.pumpAndSettle();

    expect(await result, 'edit');
    expect(find.byKey(_editKey), findsNothing);
  });

  testWidgets('全部项隐藏时直接返回 null 且不打开菜单', (tester) async {
    Future<String?>? result;
    await _pumpHost(
      tester,
      onPressed: (context) {
        result = showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(
              key: _hiddenKey,
              value: 'hidden',
              label: '隐藏项',
              visible: false,
            ),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();

    expect(await result, isNull);
    expect(find.byKey(_hiddenKey), findsNothing);
  });

  testWidgets('禁用项不响应，点击外部返回 null', (tester) async {
    Future<String?>? result;
    await _pumpHost(
      tester,
      onPressed: (context) {
        result = showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(
              key: _disabledKey,
              value: 'disabled',
              label: '不可用',
              enabled: false,
            ),
            AppMenuItem(key: _editKey, value: 'edit', label: '编辑'),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_disabledKey), findsOneWidget);

    await tester.tap(find.byKey(_disabledKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_disabledKey), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.byKey(_disabledKey), findsNothing);
  });

  testWidgets('右键和长按都从同一入口打开菜单', (tester) async {
    await _pumpContextTargetHost(tester);

    await tester.tap(
      find.byKey(_contextTargetKey),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_editKey), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(_editKey), findsNothing);

    await tester.longPress(find.byKey(_contextTargetKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_editKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required void Function(BuildContext context) onPressed,
}) {
  return _pumpApp(
    tester,
    child: Builder(
      builder: (context) => TextButton(
        key: _triggerKey,
        onPressed: () => onPressed(context),
        child: const SizedBox(width: 48, height: 32),
      ),
    ),
  );
}

Future<void> _pumpContextTargetHost(WidgetTester tester) {
  return _pumpApp(
    tester,
    child: Builder(
      builder: (context) => AppContextMenuTrigger(
        onRequestMenu: (position) {
          showAppActionMenu<String>(
            context: context,
            globalPosition: position,
            items: const <AppMenuItem<String>>[
              AppMenuItem(
                key: _editKey,
                value: 'edit',
                label: '编辑',
                icon: Icons.edit_outlined,
              ),
            ],
          );
        },
        child: const SizedBox(
          width: 120,
          height: 80,
          child: Center(child: Text('触发区', key: _contextTargetKey)),
        ),
      ),
    ),
  );
}

Future<void> _pumpApp(WidgetTester tester, {required Widget child}) async {
  await tester.pumpWidget(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraDesktopThemeData,
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
