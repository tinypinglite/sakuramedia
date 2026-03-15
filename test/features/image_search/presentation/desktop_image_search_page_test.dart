import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/media/media_preview_action_grid.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    debugImageSearchFilePicker = null;
    bundle.dispose();
  });

  testWidgets('image search page shows empty state without initial image', (
    WidgetTester tester,
  ) async {
    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
    );
    await tester.pumpAndSettle();

    expect(find.text('选择一张图片开始搜索'), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-image-search-empty-select-button')),
      findsOneWidget,
    );
  });

  testWidgets('image search page automatically searches with initial image', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
        ],
      },
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
      initialMimeType: 'image/png',
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
    expect(
      find.byKey(const Key('desktop-image-search-source-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('ABC-001'), findsNothing);
  });

  testWidgets('image search page toggles preview and filter sections', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
      surfaceSize: const Size(1440, 900),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-image-search-preview-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-preview')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-image-search-preview-panel')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsOneWidget,
    );
    expect(find.text('更换图片'), findsNothing);
    expect(find.text('展示大图'), findsNothing);
    expect(find.text('高级筛选'), findsNothing);
  });

  testWidgets(
    'image search page uses compact filter typography and button sizes',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        surfaceSize: const Size(1440, 900),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('desktop-image-search-toggle-filter')),
      );
      await tester.pumpAndSettle();

      final filterSummary = tester.widget<Text>(
        find.byKey(const Key('desktop-image-search-filter-summary')),
      );
      final noneButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, '不过滤'),
      );
      final selectActorsButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, '选择已订阅女优'),
      );
      final searchButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, '搜索'),
      );

      expect(filterSummary.style?.fontSize, 12);
      expect(noneButton.size, AppButtonSize.xSmall);
      expect(selectActorsButton.size, AppButtonSize.small);
      expect(searchButton.size, AppButtonSize.small);
    },
  );

  testWidgets(
    'image search page shows current movie scope options when available',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        currentMovieNumber: 'ABC-001',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('desktop-image-search-toggle-filter')),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前影片范围'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '全部'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '仅当前影片'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '排除当前影片'), findsOneWidget);

      final allButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, '全部'),
      );
      expect(allButton.isSelected, isTrue);
    },
  );

  testWidgets(
    'image search page filters results to current movie only after search',
    (WidgetTester tester) async {
      final responseBody = <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
          <String, dynamic>{
            'thumbnail_id': 124,
            'media_id': 457,
            'movie_id': 790,
            'movie_number': 'ABC-002',
            'offset_seconds': 240,
            'score': 0.87,
            'image': <String, dynamic>{
              'id': 11,
              'origin': '/thumb-2.webp',
              'small': '/thumb-2.webp',
              'medium': '/thumb-2.webp',
              'large': '/thumb-2.webp',
            },
          },
        ],
      };
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: responseBody,
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: responseBody,
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        currentMovieNumber: 'ABC-001',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('image-search-result-card-124'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('desktop-image-search-toggle-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅当前影片'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('image-search-result-card-124'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('image-search-result-card-124'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('image search page can exclude current movie after search', (
    WidgetTester tester,
  ) async {
    final responseBody = <String, dynamic>{
      'session_id': 'session-1',
      'status': 'ready',
      'page_size': 20,
      'next_cursor': null,
      'expires_at': '2026-03-08T10:10:00Z',
      'items': [
        <String, dynamic>{
          'thumbnail_id': 123,
          'media_id': 456,
          'movie_id': 789,
          'movie_number': 'ABC-001',
          'offset_seconds': 120,
          'score': 0.91,
          'image': <String, dynamic>{
            'id': 10,
            'origin': '/thumb-1.webp',
            'small': '/thumb-1.webp',
            'medium': '/thumb-1.webp',
            'large': '/thumb-1.webp',
          },
        },
        <String, dynamic>{
          'thumbnail_id': 124,
          'media_id': 457,
          'movie_id': 790,
          'movie_number': 'ABC-002',
          'offset_seconds': 240,
          'score': 0.87,
          'image': <String, dynamic>{
            'id': 11,
            'origin': '/thumb-2.webp',
            'small': '/thumb-2.webp',
            'medium': '/thumb-2.webp',
            'large': '/thumb-2.webp',
          },
        },
      ],
    };
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: responseBody,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: responseBody,
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
      currentMovieNumber: 'ABC-001',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('排除当前影片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key('image-search-result-card-124'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'image search page vertically centers source thumbnail and toolbar',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
      );
      await tester.pumpAndSettle();

      final thumbnailCenter = tester.getCenter(
        find.byKey(const Key('desktop-image-search-source-thumbnail')),
      );
      final toolbarCenter = tester.getCenter(
        find.byKey(const Key('desktop-image-search-toolbar-group')),
      );

      expect(
        thumbnailCenter.dy,
        moreOrLessEquals(toolbarCenter.dy, epsilon: 0.1),
      );
    },
  );

  testWidgets('image search page opens result preview dialog on result tap', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': 'ABC-001',
        'title': 'Movie 1',
        'series_name': '',
        'cover_image': <String, dynamic>{
          'id': 1,
          'origin': '/cover.jpg',
          'small': '/cover.jpg',
          'medium': '/cover.jpg',
          'large': '/cover.jpg',
        },
        'release_date': null,
        'duration_minutes': 0,
        'score': 0,
        'watched_count': 0,
        'want_watch_count': 0,
        'comment_count': 0,
        'score_number': 0,
        'is_collection': false,
        'is_subscribed': false,
        'can_play': true,
        'summary': '',
        'thin_cover_image': null,
        'plot_images': const <Map<String, dynamic>>[],
        'actors': [
          <String, dynamic>{
            'id': 2,
            'javdb_id': 'ActorA2',
            'name': '桃乃木かな',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 2,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 3,
            'javdb_id': 'ActorA3',
            'name': '三上悠亚',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 3,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 4,
            'javdb_id': 'ActorA4',
            'name': '桥本有菜',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 4,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 5,
            'javdb_id': 'ActorA5',
            'name': '天使もえ',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 5,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 6,
            'javdb_id': 'ActorA6',
            'name': '河北彩花',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 6,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 7,
            'javdb_id': 'ActorA7',
            'name': '明里紬',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 7,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 8,
            'javdb_id': 'ActorA8',
            'name': '相泽南',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 8,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 9,
            'javdb_id': 'ActorA9',
            'name': '七泽美亚',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 9,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 10,
            'javdb_id': 'ActorA10',
            'name': '小仓由菜',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 10,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 11,
            'javdb_id': 'ActorA11',
            'name': '葵司',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 11,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
          <String, dynamic>{
            'id': 12,
            'javdb_id': 'ActorA12',
            'name': '白峰美羽',
            'alias_name': '',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 12,
              'origin': '/actor.jpg',
              'small': '/actor.jpg',
              'medium': '/actor.jpg',
              'large': '/actor.jpg',
            },
          },
        ],
        'tags': const <Map<String, dynamic>>[],
        'media_items': [
          <String, dynamic>{
            'media_id': 456,
            'library_id': 1,
            'play_url':
                '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
            'path': '/library/main/ABC-001/video.mp4',
            'storage_mode': 'hardlink',
            'resolution': '1920x1080',
            'file_size_bytes': 1073741824,
            'duration_seconds': 7200,
            'special_tags': '普通',
            'valid': true,
            'progress': null,
            'points': const <Map<String, dynamic>>[],
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
      initialMimeType: 'image/png',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('image-search-result-preview-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('相似度'), findsOneWidget);
    expect(find.text('结果预览'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('image-search-result-preview-dialog')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('添加标记'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('影片详情'), findsOneWidget);
    expect(
      find.byKey(const Key('image-search-result-preview-actor-list')),
      findsOneWidget,
    );
    final actorList = tester.widget<ListView>(
      find.byKey(const Key('image-search-result-preview-actor-list')),
    );
    expect(actorList.scrollDirection, Axis.horizontal);
    expect(find.text('桃乃木かな'), findsOneWidget);
    expect(find.text('三上悠亚'), findsOneWidget);
    expect(find.text('桥本有菜'), findsOneWidget);
    expect(find.text('白峰美羽'), findsNothing);

    actorList.controller!.jumpTo(
      actorList.controller!.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();

    expect(find.text('小仓由菜'), findsOneWidget);
    expect(find.text('葵司'), findsOneWidget);
    expect(find.text('白峰美羽'), findsOneWidget);

    final dialogSize = tester.getSize(
      find.byKey(const Key('image-search-result-preview-dialog-content')),
    );
    final previewAreaSize = tester.getSize(
      find.byKey(const Key('image-search-result-preview-hero')),
    );
    expect(
      previewAreaSize.height,
      moreOrLessEquals(dialogSize.height * 0.5, epsilon: 0.5),
    );

    final dialogTopLeft = tester.getTopLeft(
      find.byKey(const Key('image-search-result-preview-dialog-content')),
    );
    final dialogTopRight = tester.getTopRight(
      find.byKey(const Key('image-search-result-preview-dialog-content')),
    );
    final previewTopLeft = tester.getTopLeft(
      find.byKey(const Key('image-search-result-preview-hero')),
    );
    final previewTopRight = tester.getTopRight(
      find.byKey(const Key('image-search-result-preview-hero')),
    );
    final baseDialogPadding = sakuraThemeData.appSpacing.xl;
    expect(
      previewTopLeft.dx,
      moreOrLessEquals(dialogTopLeft.dx + baseDialogPadding, epsilon: 0.1),
    );
    expect(
      previewTopLeft.dy,
      moreOrLessEquals(dialogTopLeft.dy + baseDialogPadding, epsilon: 0.1),
    );
    expect(
      previewTopRight.dx,
      moreOrLessEquals(dialogTopRight.dx - baseDialogPadding, epsilon: 0.1),
    );

    final actionLabel = tester.widget<Text>(find.text('相似图片'));
    expect(actionLabel.style?.fontSize, 14);
    final firstActionTile = find.ancestor(
      of: find.text('相似图片'),
      matching: find.byType(InkWell),
    );
    expect(firstActionTile, findsOneWidget);
    expect(
      tester.getTopLeft(firstActionTile).dx,
      moreOrLessEquals(dialogTopLeft.dx + baseDialogPadding, epsilon: 0.1),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('image-search-result-preview-dialog')),
        matching: find.byType(MoviePlotThumbnail),
      ),
      findsOneWidget,
    );

    final previewHeroImage = tester.widget<MaskedImage>(
      find.descendant(
        of: find.byKey(const Key('image-search-result-preview-hero')),
        matching: find.byType(MaskedImage),
      ),
    );
    expect(previewHeroImage.fit, BoxFit.contain);
    expect(
      find.descendant(
        of: find.byKey(const Key('image-search-result-preview-dialog')),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'image search page opens result preview bottom sheet when configured',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _imageSearchSessionJson(
          sessionId: 'session-bottom-sheet',
          items: [
            _imageSearchResultJson(
              thumbnailId: 123,
              mediaId: 456,
              movieId: 789,
              movieNumber: 'ABC-001',
              offsetSeconds: 120,
              score: 0.91,
              imageId: 10,
              imagePath: '/thumb-1.webp',
            ),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'score': 4.5,
          'watched_count': 12,
          'want_watch_count': 23,
          'comment_count': 34,
          'score_number': 45,
          'is_collection': false,
          'is_subscribed': true,
          'can_play': true,
          'summary': '',
          'actors': const <Map<String, dynamic>>[],
          'tags': const <Map<String, dynamic>>[],
          'thin_cover_image': null,
          'plot_images': const <Map<String, dynamic>>[],
          'media_items': const <Map<String, dynamic>>[],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/456/points',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        initialMimeType: 'image/png',
        resultPreviewPresentation:
            ImageSearchResultPreviewPresentation.bottomDrawer,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('image-search-result-preview-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('image-search-result-preview-dialog')),
        findsNothing,
      );
      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('添加标记'), findsOneWidget);
      expect(find.text('播放'), findsOneWidget);
      expect(find.text('影片详情'), findsOneWidget);

      final actionGrid = tester.widget<MediaPreviewActionGrid>(
        find.byKey(const Key('image-search-result-preview-actions')),
      );
      expect(actionGrid.layout, MediaPreviewActionGridLayout.horizontalScroll);
    },
  );

  testWidgets(
    'image search preview hides play action when media id is missing',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _imageSearchSessionJson(
          sessionId: 'session-missing-media',
          items: [
            _imageSearchResultJson(
              thumbnailId: 123,
              mediaId: 0,
              movieId: 789,
              movieNumber: 'ABC-001',
              offsetSeconds: 120,
              score: 0.91,
              imageId: 10,
              imagePath: '/thumb-1.webp',
            ),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'score': 4.5,
          'watched_count': 12,
          'want_watch_count': 23,
          'comment_count': 34,
          'score_number': 45,
          'is_collection': false,
          'is_subscribed': true,
          'can_play': true,
          'summary': '',
          'actors': const <Map<String, dynamic>>[],
          'tags': const <Map<String, dynamic>>[],
          'thin_cover_image': null,
          'plot_images': const <Map<String, dynamic>>[],
          'media_items': const <Map<String, dynamic>>[],
        },
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        initialMimeType: 'image/png',
        resultPreviewPresentation:
            ImageSearchResultPreviewPresentation.bottomDrawer,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('添加标记'), findsOneWidget);
      expect(find.text('影片详情'), findsOneWidget);
      expect(find.text('播放'), findsNothing);
    },
  );

  testWidgets(
    'image search preview falls back to movie title when actor list is empty',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': [
            <String, dynamic>{
              'thumbnail_id': 123,
              'media_id': 456,
              'movie_id': 789,
              'movie_number': 'ABC-001',
              'offset_seconds': 120,
              'score': 0.91,
              'image': <String, dynamic>{
                'id': 10,
                'origin': '/thumb-1.webp',
                'small': '/thumb-1.webp',
                'medium': '/thumb-1.webp',
                'large': '/thumb-1.webp',
              },
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'series_name': '',
          'cover_image': <String, dynamic>{
            'id': 1,
            'origin': '/cover.jpg',
            'small': '/cover.jpg',
            'medium': '/cover.jpg',
            'large': '/cover.jpg',
          },
          'release_date': null,
          'duration_minutes': 0,
          'score': 0,
          'watched_count': 0,
          'want_watch_count': 0,
          'comment_count': 0,
          'score_number': 0,
          'is_collection': false,
          'is_subscribed': false,
          'can_play': true,
          'summary': '',
          'thin_cover_image': null,
          'plot_images': const <Map<String, dynamic>>[],
          'actors': const <Map<String, dynamic>>[],
          'tags': const <Map<String, dynamic>>[],
          'media_items': [
            <String, dynamic>{
              'media_id': 456,
              'library_id': 1,
              'play_url':
                  '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
              'path': '/library/main/ABC-001/video.mp4',
              'storage_mode': 'hardlink',
              'resolution': '1920x1080',
              'file_size_bytes': 1073741824,
              'duration_seconds': 7200,
              'special_tags': '普通',
              'valid': true,
              'progress': null,
              'points': const <Map<String, dynamic>>[],
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/456/points',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        initialMimeType: 'image/png',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Movie 1'), findsOneWidget);
      expect(
        find.byKey(const Key('image-search-result-preview-actor-list')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'image search preview play action pushes player route with media and position',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': [
            <String, dynamic>{
              'thumbnail_id': 123,
              'media_id': 456,
              'movie_id': 789,
              'movie_number': 'ABC-001',
              'offset_seconds': 120,
              'score': 0.91,
              'image': <String, dynamic>{
                'id': 10,
                'origin': '/thumb-1.webp',
                'small': '/thumb-1.webp',
                'medium': '/thumb-1.webp',
                'large': '/thumb-1.webp',
              },
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'series_name': '',
          'cover_image': <String, dynamic>{
            'id': 1,
            'origin': '/cover.jpg',
            'small': '/cover.jpg',
            'medium': '/cover.jpg',
            'large': '/cover.jpg',
          },
          'release_date': null,
          'duration_minutes': 0,
          'score': 0,
          'watched_count': 0,
          'want_watch_count': 0,
          'comment_count': 0,
          'score_number': 0,
          'is_collection': false,
          'is_subscribed': false,
          'can_play': true,
          'summary': '',
          'thin_cover_image': null,
          'plot_images': const <Map<String, dynamic>>[],
          'actors': const <Map<String, dynamic>>[],
          'tags': const <Map<String, dynamic>>[],
          'media_items': [
            <String, dynamic>{
              'media_id': 456,
              'library_id': 1,
              'play_url':
                  '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
              'path': '/library/main/ABC-001/video.mp4',
              'storage_mode': 'hardlink',
              'resolution': '1920x1080',
              'file_size_bytes': 1073741824,
              'duration_seconds': 7200,
              'special_tags': '普通',
              'valid': true,
              'progress': null,
              'points': const <Map<String, dynamic>>[],
            },
          ],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/456/points',
        body: const <Map<String, dynamic>>[],
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: desktopImageSearchPath,
            builder:
                (context, state) => DesktopImageSearchPage(
                  fallbackPath: '/desktop/overview',
                  initialFileName: 'query.png',
                  initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
                  initialMimeType: 'image/png',
                ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber/player',
            builder:
                (context, state) => Text(
                  'player:${state.uri.toString()}',
                  textDirection: TextDirection.ltr,
                ),
          ),
        ],
        initialLocation: desktopImageSearchPath,
      );
      addTearDown(router.dispose);

      await _pumpImageSearchRouterApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        router: router,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('image-search-result-card-123'),
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.ancestor(of: find.text('播放'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('image-search-result-preview-dialog')),
        findsNothing,
      );
      expect(
        find.text(
          'player:/desktop/library/movies/ABC-001/player?mediaId=456&positionSeconds=120',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('image search page uses injected preview action callbacks', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: _imageSearchSessionJson(
        sessionId: 'session-override',
        items: [
          _imageSearchResultJson(
            thumbnailId: 123,
            mediaId: 456,
            movieId: 789,
            movieNumber: 'ABC-001',
            offsetSeconds: 120,
            score: 0.91,
            imageId: 10,
            imagePath: '/thumb-1.webp',
          ),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': 'ABC-001',
        'title': 'Movie 1',
        'cover_image': null,
        'release_date': null,
        'duration_minutes': 120,
        'score': 4.5,
        'watched_count': 12,
        'want_watch_count': 23,
        'comment_count': 34,
        'score_number': 45,
        'is_collection': false,
        'is_subscribed': true,
        'can_play': true,
        'summary': '',
        'actors': [],
        'tags': [],
        'thin_cover_image': null,
        'plot_images': [],
        'media_items': [],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': 'ABC-001',
        'title': 'Movie 1',
        'cover_image': null,
        'release_date': null,
        'duration_minutes': 120,
        'score': 4.5,
        'watched_count': 12,
        'want_watch_count': 23,
        'comment_count': 34,
        'score_number': 45,
        'is_collection': false,
        'is_subscribed': true,
        'can_play': true,
        'summary': '',
        'actors': [],
        'tags': [],
        'thin_cover_image': null,
        'plot_images': [],
        'media_items': [],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );

    var playTapped = false;
    var detailTapped = false;
    var similarTapped = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<ApiClient>.value(value: bundle.apiClient),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          Provider<MediaApi>(
            create: (_) => MediaApi(apiClient: bundle.apiClient),
          ),
          Provider<ImageSearchApi>(
            create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
          ),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: DesktopImageSearchPage(
                fallbackPath: desktopOverviewPath,
                initialFileName: 'query.png',
                initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
                initialMimeType: 'image/png',
                onSearchSimilar: (context, item) async {
                  similarTapped = true;
                  return true;
                },
                onOpenPlayer: (context, item) {
                  playTapped = true;
                },
                onOpenMovieDetail: (context, item) {
                  detailTapped = true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('播放'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(playTapped, isTrue);

    await tester.tap(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('影片详情'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(detailTapped, isTrue);

    await tester.tap(
      find.byKey(
        const Key('image-search-result-card-123'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('相似图片'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(similarTapped, isTrue);
  });

  testWidgets('image search page loads next result page on scroll', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: _imageSearchSessionJson(
        sessionId: 'session-1',
        nextCursor: 'cursor-1',
        items: List<Map<String, dynamic>>.generate(
          20,
          (index) => _imageSearchResultJson(
            thumbnailId: 123 + index,
            mediaId: 456 + index,
            movieId: 789 + index,
            movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
            offsetSeconds: 120 + index,
            score: 0.91,
            imageId: 10 + index,
            imagePath: '/thumb-${index + 1}.webp',
          ),
        ),
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/image-search/sessions/session-1/results',
      body: _imageSearchSessionJson(
        sessionId: 'session-1',
        items: <Map<String, dynamic>>[
          _imageSearchResultJson(
            thumbnailId: 300,
            mediaId: 600,
            movieId: 900,
            movieNumber: 'ABC-300',
            offsetSeconds: 240,
            score: 0.87,
            imageId: 300,
            imagePath: '/thumb-300.webp',
          ),
        ],
      ),
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('desktop-image-search-load-more'),
        skipOffstage: false,
      ),
      findsNothing,
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2800),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount(
        'GET',
        '/image-search/sessions/session-1/results',
      ),
      1,
    );
    expect(
      find.byKey(
        const Key('image-search-result-card-300'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'image search page keeps results and retries when auto load more fails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _imageSearchSessionJson(
          sessionId: 'session-1',
          nextCursor: 'cursor-1',
          items: List<Map<String, dynamic>>.generate(
            20,
            (index) => _imageSearchResultJson(
              thumbnailId: 400 + index,
              mediaId: 500 + index,
              movieId: 600 + index,
              movieNumber: 'DEF-${(index + 1).toString().padLeft(3, '0')}',
              offsetSeconds: 60 + index,
              score: 0.89,
              imageId: 100 + index,
              imagePath: '/def-${index + 1}.webp',
            ),
          ),
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('image-search-result-card-400'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text('加载更多失败，请稍后重试'), findsOneWidget);
      expect(
        find.byKey(
          const Key('desktop-image-search-load-more'),
          skipOffstage: false,
        ),
        findsNothing,
      );

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        body: _imageSearchSessionJson(
          sessionId: 'session-1',
          items: <Map<String, dynamic>>[
            _imageSearchResultJson(
              thumbnailId: 999,
              mediaId: 999,
              movieId: 999,
              movieNumber: 'DEF-999',
              offsetSeconds: 999,
              score: 0.95,
              imageId: 999,
              imagePath: '/def-999.webp',
            ),
          ],
        ),
      );

      await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount(
          'GET',
          '/image-search/sessions/session-1/results',
        ),
        2,
      );
      expect(find.text('加载更多失败，请稍后重试'), findsNothing);
      expect(
        find.byKey(
          const Key('image-search-result-card-999'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'image search page auto loads more when first page does not fill viewport',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _imageSearchSessionJson(
          sessionId: 'session-1',
          nextCursor: 'cursor-1',
          items: <Map<String, dynamic>>[
            _imageSearchResultJson(
              thumbnailId: 123,
              mediaId: 456,
              movieId: 789,
              movieNumber: 'ABC-001',
              offsetSeconds: 120,
              score: 0.91,
              imageId: 10,
              imagePath: '/thumb-1.webp',
            ),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        body: _imageSearchSessionJson(
          sessionId: 'session-1',
          items: <Map<String, dynamic>>[
            _imageSearchResultJson(
              thumbnailId: 124,
              mediaId: 457,
              movieId: 790,
              movieNumber: 'ABC-002',
              offsetSeconds: 240,
              score: 0.87,
              imageId: 11,
              imagePath: '/thumb-2.webp',
            ),
          ],
        ),
      );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        surfaceSize: const Size(1440, 1600),
      );
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount(
          'GET',
          '/image-search/sessions/session-1/results',
        ),
        1,
      );
      expect(
        find.byKey(
          const Key('image-search-result-card-124'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('desktop-image-search-load-more'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'image search page changes image and automatically searches again',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-2',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': [
            <String, dynamic>{
              'thumbnail_id': 200,
              'media_id': 300,
              'movie_id': 400,
              'movie_number': 'XYZ-200',
              'offset_seconds': 30,
              'score': 0.95,
              'image': <String, dynamic>{
                'id': 99,
                'origin': '/thumb-200.webp',
                'small': '/thumb-200.webp',
                'medium': '/thumb-200.webp',
                'large': '/thumb-200.webp',
              },
            },
          ],
        },
      );
      debugImageSearchFilePicker =
          () async => ImageSearchPickedFile(
            bytes: Uint8List.fromList(const <int>[5, 6, 7, 8]),
            fileName: 'changed.png',
            mimeType: 'image/png',
          );

      await _pumpImageSearchApp(
        tester,
        bundle: bundle,
        sessionStore: sessionStore,
        initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        initialFileName: 'query.png',
        initialMimeType: 'image/png',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('desktop-image-search-change-image')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 2);
      final latestRequest = bundle.adapter.requests.last;
      expect(
        (latestRequest.body as dynamic).files.single.value.filename,
        'changed.png',
      );
      expect(
        find.byKey(
          const Key('image-search-result-card-200'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('image search page applies actor include filter on search', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': '三上悠亚',
            'alias_name': '三上悠亚',
            'profile_image': null,
            'is_subscribed': true,
          },
        ],
        'page': 1,
        'page_size': 200,
        'total': 1,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1/movie-ids',
      body: <int>[101, 102],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-2',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );

    await _pumpImageSearchApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      initialFileName: 'query.png',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅包含所选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择已订阅女优'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('desktop-image-search-actor-option-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('GET', '/actors/1/movie-ids'), 1);
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 2);
    final latestRequest = bundle.adapter.requests.last;
    final formFields = Map<String, String>.fromEntries(
      (latestRequest.body as dynamic).fields,
    );
    expect(formFields['movie_ids'], '101,102');
  });

  testWidgets('image search page opens result action menu on secondary tap', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: desktopImageSearchPath,
          builder:
              (context, state) => DesktopImageSearchPage(
                fallbackPath: '/desktop/overview',
                initialFileName: 'query.png',
                initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
                initialMimeType: 'image/png',
              ),
        ),
      ],
      initialLocation: desktopImageSearchPath,
    );
    addTearDown(router.dispose);

    await _pumpImageSearchRouterApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      router: router,
    );
    await tester.pumpAndSettle();

    final resultCard = find.byKey(
      const Key('image-search-result-card-123'),
      skipOffstage: false,
    );
    await tester.tapAt(
      tester.getCenter(resultCard),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('添加标记'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('影片详情'), findsOneWidget);
  });

  testWidgets('image search page result action toggles media point', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/456/points',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media/456/points',
      body: <String, dynamic>{
        'point_id': 900,
        'media_id': 456,
        'offset_seconds': 120,
        'created_at': '2026-03-08T10:10:00Z',
      },
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: desktopImageSearchPath,
          builder:
              (context, state) => DesktopImageSearchPage(
                fallbackPath: '/desktop/overview',
                initialFileName: 'query.png',
                initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
                initialMimeType: 'image/png',
              ),
        ),
      ],
      initialLocation: desktopImageSearchPath,
    );
    addTearDown(router.dispose);

    await _pumpImageSearchRouterApp(
      tester,
      bundle: bundle,
      sessionStore: sessionStore,
      router: router,
    );
    await tester.pumpAndSettle();

    final resultCard = find.byKey(
      const Key('image-search-result-card-123'),
      skipOffstage: false,
    );
    await tester.tapAt(
      tester.getCenter(resultCard),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加标记'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(bundle.adapter.hitCount('POST', '/media/456/points'), 1);
  });
}

Future<void> _pumpImageSearchApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
  Uint8List? initialFileBytes,
  String? initialFileName,
  String? initialMimeType,
  String? currentMovieNumber,
  ImageSearchCurrentMovieScope initialCurrentMovieScope =
      ImageSearchCurrentMovieScope.all,
  ImageSearchResultPreviewPresentation resultPreviewPresentation =
      ImageSearchResultPreviewPresentation.dialog,
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
        Provider<ImageSearchApi>(
          create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: DesktopImageSearchPage(
              fallbackPath: '/desktop/overview',
              initialFileName: initialFileName,
              initialFileBytes: initialFileBytes,
              initialMimeType: initialMimeType,
              currentMovieNumber: currentMovieNumber,
              initialCurrentMovieScope: initialCurrentMovieScope,
              resultPreviewPresentation: resultPreviewPresentation,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpImageSearchRouterApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
        Provider<ImageSearchApi>(
          create: (_) => ImageSearchApi(apiClient: bundle.apiClient),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

Map<String, dynamic> _imageSearchSessionJson({
  required String sessionId,
  String? nextCursor,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    'session_id': sessionId,
    'status': 'ready',
    'page_size': 20,
    'next_cursor': nextCursor,
    'expires_at': '2026-03-08T10:10:00Z',
    'items': items,
  };
}

Map<String, dynamic> _imageSearchResultJson({
  required int thumbnailId,
  required int mediaId,
  required int movieId,
  required String movieNumber,
  required int offsetSeconds,
  required double score,
  required int imageId,
  required String imagePath,
}) {
  return <String, dynamic>{
    'thumbnail_id': thumbnailId,
    'media_id': mediaId,
    'movie_id': movieId,
    'movie_number': movieNumber,
    'offset_seconds': offsetSeconds,
    'score': score,
    'image': <String, dynamic>{
      'id': imageId,
      'origin': imagePath,
      'small': imagePath,
      'medium': imagePath,
      'large': imagePath,
    },
  };
}
