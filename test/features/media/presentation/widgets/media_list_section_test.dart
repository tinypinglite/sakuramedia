import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('长媒体列表固定行高虚拟化并支持底部直接跳回顶部', (tester) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);

    const itemCount = 120;
    const pageSize = 30;
    for (var page = 1; page <= itemCount ~/ pageSize; page++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: <String, dynamic>{
          'items': List<Map<String, dynamic>>.generate(
            pageSize,
            (index) => _mediaItemJson((page - 1) * pageSize + index + 1),
          ),
          'page': page,
          'page_size': pageSize,
          'total': itemCount,
        },
      );
    }
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MediaApi>.value(value: bundle.mediaApi),
        ],
        child: ProviderScope(
          overrides: [
            mediaApiProvider.overrideWithValue(bundle.mediaApi),
            mediaLibrariesApiProvider.overrideWithValue(
              bundle.mediaLibrariesApi,
            ),
          ],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: MediaListSection(
                scrollController: scrollController,
                isTriggering: false,
                isDeleting: false,
                onRapidUpload: _noOp,
                onBatchDelete: _noOp,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-list-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('共 120 条'), findsOneWidget);
    expect(find.byType(SliverFixedExtentList), findsOneWidget);
    expect(
      find.byType(AppLeftCoverCard).evaluate().length,
      lessThan(itemCount),
      reason: '固定尺寸 Sliver 应只挂载视口附近的媒体卡片',
    );
    expect(
      tester.getSize(find.byKey(const Key('media-management-row-1'))).height,
      144,
    );
    expect(find.byKey(const Key('media-management-row-120')), findsNothing);

    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pump();
    expect(find.text('共 120 条 · 已选 1 项'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaListSection)),
    );
    for (var page = 2; page <= itemCount ~/ pageSize; page++) {
      await tester.runAsync(
        () => container.read(mediaBrowseProvider.notifier).loadMore(),
      );
      await tester.pump();
    }
    expect(
      container.read(mediaBrowseProvider).requireValue.paged.items,
      hasLength(itemCount),
      reason: '回归场景需要先累计加载多页，再执行滚动条大跨度反向跳转',
    );
    await tester.pumpAndSettle();
    expect(
      scrollController.position.maxScrollExtent,
      greaterThan(itemCount * 140),
      reason: '累计页写入后，固定尺寸 Sliver 应同步扩展可滚动范围',
    );

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    expect(find.byKey(const Key('media-management-row-120')), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-row-1')),
      findsNothing,
      reason: '离开缓存区的首项应被固定尺寸 Sliver 回收',
    );

    scrollController.jumpTo(0);
    await tester.pump();

    expect(find.byKey(const Key('media-management-row-1')), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-row-120')),
      findsNothing,
      reason: '大跨度反向跳转应在一帧内恢复顶部可见项，而非测量中间所有行',
    );
  });
}

Future<void> _noOp() async {}

Map<String, dynamic> _mediaItemJson(int id) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'path': '/library/main/abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'special_tags': '普通',
    'valid': true,
    'heat': 100,
    'last_rapid_upload_status': null,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
