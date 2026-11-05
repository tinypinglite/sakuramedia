import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';

void main() {
  testWidgets('内容不足一屏时无需滚动自动触发', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      _ScopeHarness(
        itemCount: 1,
        itemExtent: 40,
        onLoadMore: () async => calls++,
      ),
    );
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('内容超过一屏时不预取，滚到底后才触发', (tester) async {
    var calls = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _ScopeHarness(
        controller: controller,
        itemCount: 20,
        itemExtent: 100,
        onLoadMore: () async => calls++,
      ),
    );
    await tester.pump();
    expect(calls, 0);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('窗口变高后重新检查并补页', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var calls = 0;

    await tester.pumpWidget(
      _ScopeHarness(
        itemCount: 10,
        itemExtent: 100,
        onLoadMore: () async => calls++,
      ),
    );
    await tester.pump();
    expect(calls, 0);

    tester.view.physicalSize = const Size(400, 1400);
    await tester.pump();
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('canLoadMore 变为 true 时即使布局不变也补查', (tester) async {
    var calls = 0;
    final harnessKey = GlobalKey<_ScopeHarnessState>();

    await tester.pumpWidget(
      _ScopeHarness(
        key: harnessKey,
        itemCount: 1,
        itemExtent: 40,
        canLoadMore: false,
        onLoadMore: () async => calls++,
      ),
    );
    await tester.pump();
    expect(calls, 0);

    harnessKey.currentState!.setCanLoadMore(true);
    await tester.pump();

    expect(calls, 1);
  });

  testWidgets('加载 Future 未完成时不会重复触发', (tester) async {
    var calls = 0;
    final loadMore = Completer<void>();

    await tester.pumpWidget(
      _ScopeHarness(
        itemCount: 1,
        itemExtent: 40,
        onLoadMore: () {
          calls++;
          return loadMore.future;
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(calls, 1);

    loadMore.complete();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('enabled 为 false 或 TickerMode 关闭时不触发', (tester) async {
    var enabled = false;
    var tickerEnabled = false;
    var calls = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return TickerMode(
            enabled: tickerEnabled,
            child: _ScopeHarness(
              itemCount: 1,
              itemExtent: 40,
              enabled: enabled,
              onLoadMore: () async => calls++,
            ),
          );
        },
      ),
    );
    await tester.pump();
    expect(calls, 0);

    rebuild(() => enabled = true);
    await tester.pump();
    expect(calls, 0, reason: 'TickerMode 仍关闭');

    rebuild(() => tickerEnabled = true);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('嵌套横向滚动不会触发外层分页', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPagedLoadMoreScope(
            canLoadMore: () => true,
            onLoadMore: () async => calls++,
            child: ListView(
              children: [
                SizedBox(
                  height: 100,
                  child: ListView(
                    key: const Key('horizontal-list'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var index = 0; index < 20; index++)
                        const SizedBox(width: 100, height: 100),
                    ],
                  ),
                ),
                for (var index = 0; index < 20; index++)
                  const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);

    await tester.drag(
      find.byKey(const Key('horizontal-list')),
      const Offset(-500, 0),
    );
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('追加内容后不会用旧 metrics 多翻一页', (tester) async {
    var calls = 0;
    late StateSetter rebuild;
    var itemCount = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AppPagedLoadMoreScope(
                canLoadMore: () => true,
                onLoadMore: () async {
                  calls++;
                  if (calls == 1) {
                    rebuild(() => itemCount = 20);
                  }
                },
                child: ListView.builder(
                  itemCount: itemCount,
                  itemExtent: 100,
                  itemBuilder: (_, __) => const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1, reason: '追加一页已足够铺满视口，不应再预取下一页');
  });

  testWidgets('兄弟级横向滚动不会驱动分页', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPagedLoadMoreScope(
            canLoadMore: () => true,
            onLoadMore: () async => calls++,
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: ListView(
                    key: const Key('sibling-horizontal-list'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var index = 0; index < 20; index++)
                        const SizedBox(width: 100, height: 80),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 30,
                    itemExtent: 100,
                    itemBuilder: (_, __) => const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);

    await tester.drag(
      find.byKey(const Key('sibling-horizontal-list')),
      const Offset(-2000, 0),
    );
    await tester.pump();
    await tester.pump();

    expect(calls, 0, reason: '横向列表与纵向列表是兄弟，不应触发纵向分页');
  });
}

class _ScopeHarness extends StatefulWidget {
  const _ScopeHarness({
    super.key,
    this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.onLoadMore,
    this.canLoadMore = true,
    this.enabled = true,
  });

  final ScrollController? controller;
  final int itemCount;
  final double itemExtent;
  final Future<void> Function() onLoadMore;
  final bool canLoadMore;
  final bool enabled;

  @override
  State<_ScopeHarness> createState() => _ScopeHarnessState();
}

class _ScopeHarnessState extends State<_ScopeHarness> {
  late bool _canLoadMore = widget.canLoadMore;

  void setCanLoadMore(bool value) {
    setState(() => _canLoadMore = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AppPagedLoadMoreScope(
          enabled: widget.enabled,
          canLoadMore: () => _canLoadMore,
          onLoadMore: widget.onLoadMore,
          child: ListView.builder(
            controller: widget.controller,
            itemCount: widget.itemCount,
            itemBuilder: (context, index) =>
                SizedBox(height: widget.itemExtent),
          ),
        ),
      ),
    );
  }
}
