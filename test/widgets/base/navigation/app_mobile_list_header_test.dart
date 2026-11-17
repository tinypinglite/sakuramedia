import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('四个图标操作在窄屏下可用且不溢出', (tester) async {
    final taps = <int>[];
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppMobileListHeader(
          leading: const AppMobileHeaderText(title: '全部影片', countLabel: '24 部'),
          actions: <Widget>[
            for (var index = 0; index < 4; index++)
              AppGlassIconButton(
                key: Key('action-$index'),
                tooltip: '动作 $index',
                icon: Icons.tune_rounded,
                onPressed: () => taps.add(index),
              ),
          ],
        ),
      ),
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(360, 300),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(Key('action-$index')));
    }
    await tester.pumpAndSettle();

    expect(taps, <int>[0, 1, 2, 3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('紧凑多选头回传退出和全选', (tester) async {
    var exitCount = 0;
    var toggleAllCount = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppMobileSelectionHeader(
          selectionLabel: '已选 2 项',
          exitKey: const Key('selection-exit'),
          selectAllKey: const Key('selection-all'),
          onExitSelection: () => exitCount++,
          onToggleAll: () => toggleAllCount++,
        ),
      ),
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(360, 300),
    );

    await tester.tap(find.byKey(const Key('selection-exit')));
    await tester.tap(find.byKey(const Key('selection-all')));

    expect(exitCount, 1);
    expect(toggleAllCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('筛选失败在移动控制条内只出现一条反馈', (tester) async {
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppMobileListHeader(
          leading: const AppMobileHeaderText(title: '全部影片'),
          filterUpdate: const FilterUpdateState.failed('加载失败'),
          hasPreviousFilterItems: true,
        ),
      ),
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(390, 400),
    );

    expect(find.byKey(const Key('app-filter-update-error')), findsOneWidget);
    expect(
      find.byKey(const Key('app-filter-update-empty-error')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
