import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('initial loading keeps the desktop clips layout as skeletons', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipsOverviewProvider.overrideWith(_LoadingClipsOverview.new),
          clipCollectionsOverviewProvider.overrideWith(
            _LoadingClipCollectionsOverview.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopClipsPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeletonizer), findsNWidgets(2));
    expect(find.text('切片合集'), findsOneWidget);
    expect(find.text('我的合集'), findsNothing);
    // 加载态渲染的是真实卡片（占位数据），骨架即真实布局。
    expect(find.byKey(const Key('clips-collections-row')), findsOneWidget);
    expect(find.byType(CollectionCard), findsWidgets);
    expect(find.byType(ClipGridCard), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping a clip opens the actions dialog instead of playing', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipsOverviewProvider.overrideWith(_PopulatedClipsOverview.new),
          clipCollectionsOverviewProvider.overrideWith(
            _EmptyClipCollectionsOverview.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopClipsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('clip-grid-card-tap-1')),
    );
    await tester.tap(find.byKey(const Key('clip-grid-card-tap-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clip-actions-dialog')), findsOneWidget);
    expect(find.byKey(const Key('clip-action-play')), findsOneWidget);
    expect(find.byKey(const Key('clip-action-movie')), findsOneWidget);
    expect(
      find.byKey(const Key('clip-action-add-to-collection')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clip-action-rename')), findsOneWidget);
    expect(find.byKey(const Key('clip-action-delete')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('进入选择原地改写操作行，合集区与网格位置不变', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipsOverviewProvider.overrideWith(_PopulatedClipsOverview.new),
          clipCollectionsOverviewProvider.overrideWith(
            _PopulatedClipCollectionsOverview.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopClipsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerHeight = tester.getSize(find.byType(AppListHeader)).height;
    final cardTop = tester
        .getTopLeft(find.byKey(const Key('clip-grid-card-1')))
        .dy;

    await tester.tap(find.byKey(const Key('clips-enter-selection-button')));
    await tester.pumpAndSettle();

    // 常规顶栏被替换掉，而不是在它下方再加一行。
    expect(find.byType(AppListHeader), findsNothing);
    expect(find.byType(AppSelectionHeaderToolbar), findsOneWidget);
    expect(find.byKey(const Key('clips-select-all-button')), findsOneWidget);
    expect(
      find.byKey(const Key('clips-batch-add-collection-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clips-batch-delete-button')), findsOneWidget);
    // 选择态不再显示排序。
    expect(find.byKey(const Key('clips-sort-latest')), findsNothing);

    // 进出多选不跳版：操作行等高，合集区与网格位置不变。
    expect(
      tester.getSize(find.byType(AppSelectionHeaderToolbar)).height,
      headerHeight,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('clip-grid-card-1'))).dy,
      closeTo(cardTop, 0.1),
    );
    expect(find.byKey(const Key('clips-collections-row')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clips-exit-selection-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppSelectionHeaderToolbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('批量加入合集提交 clip_collection_add 且 ids 是 clip_id', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sessionStore = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 7,
        'task_key': 'batch_operation',
        'state': 'pending',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bundle.riverpodOverrides(),
          clipsOverviewProvider.overrideWith(_PopulatedClipsOverview.new),
          clipCollectionsOverviewProvider.overrideWith(
            _PopulatedClipCollectionsOverview.new,
          ),
        ],
        child: OKToast(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: sakuraDesktopThemeData,
            home: const Scaffold(body: DesktopClipsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clips-enter-selection-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clip-grid-card-tap-1')));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 个'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('clips-batch-add-collection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-clip-collection-7')));
    await tester.pumpAndSettle();

    final submit = bundle.adapter.requests
        .where((request) => request.path == '/batch-operations')
        .toList();
    expect(submit, hasLength(1));
    expect(submit.single.body, {
      'operation': 'clip_collection_add',
      'ids': [1],
      'target_collection_id': 7,
      'delete_files': false,
    });
    expect(
      bundle.adapter.hitCount('PUT', '/clip-collections/7/clips/1'),
      0,
    );
    expect(find.text('已选 1 个'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}

class _LoadingClipsOverview extends ClipsOverview {
  @override
  Future<ClipsOverviewState> build() => Completer<ClipsOverviewState>().future;
}

class _LoadingClipCollectionsOverview extends ClipCollectionsOverview {
  @override
  Future<List<ClipCollectionDto>> build() =>
      Completer<List<ClipCollectionDto>>().future;
}

class _PopulatedClipsOverview extends ClipsOverview {
  @override
  Future<ClipsOverviewState> build() async {
    return ClipsOverviewState(
      paged: PagedListState<MediaClipDto>(
        items: <MediaClipDto>[
          const MediaClipDto(
            clipId: 1,
            mediaId: 1,
            movieNumber: 'ABC-001',
            startOffsetSeconds: 120,
            endOffsetSeconds: 300,
            title: '精彩片段',
            durationSeconds: 180,
            fileSizeBytes: 15728640,
            coverImage: null,
            streamUrl: '/media-clips/1/stream',
            createdAt: null,
          ),
        ],
        currentPage: 1,
        total: 1,
      ),
    );
  }
}

class _EmptyClipCollectionsOverview extends ClipCollectionsOverview {
  @override
  Future<List<ClipCollectionDto>> build() async =>
      const <ClipCollectionDto>[];
}

class _PopulatedClipCollectionsOverview extends ClipCollectionsOverview {
  @override
  Future<List<ClipCollectionDto>> build() async {
    return const <ClipCollectionDto>[
      ClipCollectionDto(
        id: 7,
        name: '我的合集',
        description: '',
        clipCount: 1,
        coverImage: null,
        createdAt: null,
        updatedAt: null,
      ),
    ];
  }
}
