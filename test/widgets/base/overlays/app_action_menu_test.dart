import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
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

  testWidgets('桌面 popup 打开时不预选且不渲染图标', (tester) async {
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(
              key: _editKey,
              value: 'edit',
              label: '编辑',
              icon: Icons.edit_outlined,
            ),
            AppMenuItem(
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

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(_rowBackground(tester, _editKey), Colors.transparent);
    expect(_rowBackground(tester, _deleteKey), Colors.transparent);
  });

  testWidgets('鼠标 hover 只保留一个视觉落点', (tester) async {
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(key: _editKey, value: 'edit', label: '编辑'),
            AppMenuItem(key: _deleteKey, value: 'delete', label: '删除'),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byKey(_deleteKey)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(_rowBackground(tester, _editKey), Colors.transparent);
    expect(_rowBackground(tester, _deleteKey), _activeRowBackground());
  });

  testWidgets('键盘移动跳过禁用项，Enter 激活，Escape 关闭', (tester) async {
    Future<String?>? result;
    await _pumpHost(
      tester,
      onPressed: (context) {
        result = showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(key: _editKey, value: 'edit', label: '编辑'),
            AppMenuItem(
              key: _disabledKey,
              value: 'disabled',
              label: '不可用',
              enabled: false,
            ),
            AppMenuItem(key: _deleteKey, value: 'delete', label: '删除'),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_rowBackground(tester, _editKey), _activeRowBackground());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_rowBackground(tester, _editKey), Colors.transparent);
    expect(_rowBackground(tester, _deleteKey), _activeRowBackground());

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, 'delete');

    result = null;
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(find.byKey(_editKey), findsNothing);
  });

  testWidgets('组间线只由 showDividerBefore 控制', (tester) async {
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
          items: const <AppMenuItem<String>>[
            AppMenuItem(key: _editKey, value: 'edit', label: '编辑'),
            AppMenuItem(
              key: _deleteKey,
              value: 'delete',
              label: '删除',
              showDividerBefore: true,
            ),
            AppMenuItem(
              key: _disabledKey,
              value: 'disabled',
              label: '不可用',
              enabled: false,
            ),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsOneWidget);
    expect(find.byKey(_editKey), findsOneWidget);
    expect(find.byKey(_deleteKey), findsOneWidget);
  });

  testWidgets('flat 模式复用同一菜单结构', (tester) async {
    await _pumpHost(
      tester,
      flat: true,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(400, 300),
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
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-glass-flat-surface')), findsOneWidget);
    expect(find.byKey(_editKey), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('窄屏长文案保持单行省略且不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longLabel = '这是一个非常非常长的菜单动作名称，用来验证窄屏下的省略布局';
    const longSubtitle = '副标题也同样很长，应该限制为一行并在可用宽度内省略';
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          globalPosition: const Offset(160, 120),
          items: const <AppMenuItem<String>>[
            AppMenuItem(
              key: _editKey,
              value: 'edit',
              label: longLabel,
              subtitle: longSubtitle,
            ),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text(longLabel));
    final subtitle = tester.widget<Text>(find.text(longSubtitle));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(subtitle.maxLines, 1);
    expect(subtitle.overflow, TextOverflow.ellipsis);
  });

  testWidgets('窄屏低高度时长菜单可在面板内滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final items = <AppMenuItem<int>>[
      for (var index = 0; index < 12; index++)
        AppMenuItem(
          key: Key('action-menu-item-$index'),
          value: index,
          label: '动作 $index',
        ),
    ];
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<int>(
          context: context,
          globalPosition: const Offset(160, 110),
          items: items,
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('底部操作表继续显示图标', (tester) async {
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<String>(
          context: context,
          presentation: AppMenuPresentation.bottomDrawer,
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
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_editKey), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('底部操作表溢出时显示下滑提示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpHost(
      tester,
      onPressed: (context) {
        showAppActionMenu<int>(
          context: context,
          presentation: AppMenuPresentation.bottomDrawer,
          title: '影片操作',
          items: <AppMenuItem<int>>[
            for (var index = 0; index < 12; index++)
              AppMenuItem(
                key: Key('action-drawer-item-$index'),
                value: index,
                label: '动作 $index',
              ),
          ],
        );
      },
    );

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final cue = find.byKey(const Key('app-bottom-drawer-scroll-cue'));
    expect(cue, findsOneWidget);
    for (var index = 0; index < 10 && cue.evaluate().isNotEmpty; index++) {
      await tester.tap(cue);
      await tester.pumpAndSettle();
    }
    expect(cue, findsNothing);
    await tester.tap(find.byKey(const Key('action-drawer-item-11')));
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required void Function(BuildContext context) onPressed,
  bool flat = false,
}) {
  return _pumpApp(
    tester,
    flat: flat,
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required Widget child,
  bool flat = false,
}) async {
  await tester.pumpWidget(
    AppSurfaceRuntime.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: AppSurfaceStyleScope(
        style: flat ? AppSurfaceStyle.flat : AppSurfaceStyle.liquid,
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
    ),
  );
  await tester.pumpAndSettle();
}

Color? _rowBackground(WidgetTester tester, Key key) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

Color _activeRowBackground() {
  return Color.alphaBlend(
    sakuraDesktopThemeData.appTextPalette.primary.withValues(alpha: 0.10),
    sakuraDesktopThemeData.appColors.surfaceMuted,
  );
}
