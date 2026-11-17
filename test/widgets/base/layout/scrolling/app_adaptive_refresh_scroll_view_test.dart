import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

const double _kViewportHeight = 800;
const double _kContentHeight = 2000;

void main() {
  testWidgets('底部安全区补在滚动末尾', (WidgetTester tester) async {
    // 移动子页外壳不吞底部安全区：滚动内容铺到屏幕物理底边，末尾补等高留白，
    // 最后一块内容不会被 home indicator 压住。
    await _pumpScrollView(tester, bottomInset: 34);

    expect(
      _scrollPosition(tester).maxScrollExtent,
      moreOrLessEquals(_kContentHeight + 34 - _kViewportHeight),
    );
  });

  testWidgets('没有底部安全区时不留额外留白', (WidgetTester tester) async {
    // 桌面、tab 壳内（Scaffold removeBottomPadding）和抽屉里读到的都是 0，
    // 滚动范围与补丁前完全一致。
    await _pumpScrollView(tester, bottomInset: 0);

    expect(
      _scrollPosition(tester).maxScrollExtent,
      moreOrLessEquals(_kContentHeight - _kViewportHeight),
    );
  });

  testWidgets('关闭下拉刷新时保留底部安全区且不触发刷新', (WidgetTester tester) async {
    var refreshCount = 0;
    await _pumpScrollView(
      tester,
      bottomInset: 34,
      enableRefresh: false,
      onRefresh: () async => refreshCount++,
    );

    expect(
      _scrollPosition(tester).maxScrollExtent,
      moreOrLessEquals(_kContentHeight + 34 - _kViewportHeight),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(refreshCount, 0);
  });
}

Future<void> _pumpScrollView(
  WidgetTester tester, {
  required double bottomInset,
  bool enableRefresh = true,
  Future<void> Function()? onRefresh,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, _kViewportHeight);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: AppAdaptiveRefreshScrollView(
          onRefresh: onRefresh ?? () async {},
          enableRefresh: enableRefresh,
          slivers: const <Widget>[
            SliverToBoxAdapter(child: SizedBox(height: _kContentHeight)),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _scrollPosition(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable)).position;
}
