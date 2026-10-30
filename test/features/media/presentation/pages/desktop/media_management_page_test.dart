import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/pages/desktop/media_management_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operations_api.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operations_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    mediaApi = MediaApi(apiClient: apiClient);
    adapter.setFallbackJson(method: 'GET', path: '/media', body: _emptyPage());
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders supported tabs and lazy-loads management sections', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 0, items: const []),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _page(total: 0, items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(find.byKey(const Key('media-management-tab-list')), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-sort-trigger')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-search-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );
    // 筛选与排序贴左；搜索入口固定在刷新之后的右侧末位。
    final filterRect = tester.getRect(
      find.byKey(const Key('media-management-filter-trigger')),
    );
    final searchToggleRect = tester.getRect(
      find.byKey(const Key('media-management-search-toggle')),
    );
    final sortRect = tester.getRect(
      find.byKey(const Key('media-management-sort-trigger')),
    );
    final selectRect = tester.getRect(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    final refreshRect = tester.getRect(
      find.byKey(const Key('media-management-refresh-button')),
    );
    expect(filterRect.left, lessThan(100));
    expect(filterRect.center.dy, closeTo(searchToggleRect.center.dy, 0.5));
    expect(filterRect.center.dy, closeTo(sortRect.center.dy, 0.5));
    expect(sortRect.left - filterRect.right, closeTo(4, 0.5));
    expect(refreshRect.left - selectRect.right, closeTo(4, 0.5));
    expect(searchToggleRect.left - refreshRect.right, closeTo(4, 0.5));
    expect(searchToggleRect.left, greaterThan(refreshRect.right));
    expect(
      find.byKey(const Key('media-management-tab-maintenance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-tab-duplicates')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('media-management-tab-batches')), findsNothing);
    expect(adapter.hitCount('GET', '/media/duplicates'), 0);
    expect(adapter.hitCount('GET', '/media/invalid'), 0);

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('GET', '/media/duplicates'), 1);
    expect(
      find.byKey(const Key('media-management-duplicate-media-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('media-management-tab-maintenance')));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('GET', '/media/invalid'), 1);
    expect(
      find.byKey(const Key('media-management-invalid-media-section')),
      findsOneWidget,
    );
  });

  testWidgets('opens compact file name search from the rightmost action', (
    tester,
  ) async {
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );
    final collapsedSearchToggleRect = tester.getRect(
      find.byKey(const Key('media-management-search-toggle')),
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-filter-trigger')),
      findsOneWidget,
    );
    expect(find.byTooltip('收起搜索'), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-total-text')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-sort-trigger')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-enter-selection-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-refresh-button')),
      findsNothing,
    );

    final fieldRect = tester.getRect(
      find.byKey(const Key('media-management-search-field')),
    );
    expect(fieldRect.height, 36);
    final editableRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    final searchIconRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byIcon(Icons.search_rounded),
      ),
    );
    final expandedSearchToggleRect = tester.getRect(
      find.byKey(const Key('media-management-search-toggle')),
    );
    expect(
      tester
          .getRect(
            find.byKey(const Key('media-management-filter-trigger')),
          )
          .center
          .dy,
      closeTo(fieldRect.center.dy, 0.5),
    );
    expect(
      expandedSearchToggleRect.center.dy,
      closeTo(fieldRect.center.dy, 0.5),
    );
    expect(editableRect.center.dy, closeTo(fieldRect.center.dy, 0.5));
    expect(searchIconRect.center.dy, closeTo(fieldRect.center.dy, 0.5));
    expect(
      expandedSearchToggleRect.center.dx,
      closeTo(collapsedSearchToggleRect.center.dx, 0.5),
    );
    expect(expandedSearchToggleRect.left - fieldRect.right, closeTo(8, 0.5));
    final fieldContext = tester.element(
      find.byKey(const Key('media-management-search-field')),
    );
    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(TextField),
      ),
    );
    final decoration = textField.decoration!;
    expect(textField.textAlignVertical, TextAlignVertical.center);
    expect(
      (decoration.border! as OutlineInputBorder).borderRadius,
      Theme.of(fieldContext).appRadius.smBorder,
    );
    expect(decoration.prefixIcon, isNotNull);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('media-management-search-field')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-sort-trigger')),
      findsOneWidget,
    );
  });

  testWidgets('searches by file name on submit and clears immediately', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 0, items: const []),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-management-search-field')),
      '  abc-1  ',
    );
    await _submitSearch(
      tester,
      const Key('media-management-search-field'),
    );

    expect(adapter.requests.last.uri.queryParameters['search'], 'abc-1');
    expect(
      find.byKey(const Key('media-management-search-clear')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, 'abc-1');

    await tester.tap(find.byKey(const Key('media-management-search-clear')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.last.uri.queryParameters.containsKey('search'),
      isFalse,
    );
  });

  testWidgets('discards an unsubmitted search draft when collapsed', (
    tester,
  ) async {
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-management-search-field')),
      'draft',
    );
    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, isEmpty);
    expect(
      adapter.requests.where(
        (request) => request.uri.queryParameters.containsKey('search'),
      ),
      isEmpty,
    );
  });

  testWidgets('resetting filters clears the filename search', (tester) async {
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-management-search-field')),
      'abc',
    );
    await _submitSearch(
      tester,
      const Key('media-management-search-field'),
    );
    await tester.tap(find.byKey(const Key('media-management-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.last.uri.queryParameters.containsKey('search'),
      isFalse,
    );
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, isEmpty);
  });

  testWidgets('keeps the submitted search after a filter request fails', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _emptyPage(),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': '搜索暂不可用',
        },
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-management-search-field')),
      'abc',
    );
    await _submitSearch(
      tester,
      const Key('media-management-search-field'),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('搜索暂不可用'), findsOneWidget);
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, 'abc');
  });

  testWidgets('shows duplicate groups and removes the final duplicate copy', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 1, items: [_duplicateGroupJson()]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-duplicate-group-1')),
      findsOneWidget,
    );
    expect(find.text('abc-1.mp4'), findsOneWidget);
    expect(find.text('重复文件组'), findsNothing);
    expect(find.text('以下媒体内容相同，分别来自不同媒体记录。'), findsNothing);
    expect(find.textContaining('hash'), findsNothing);

    await tester.tap(
      find.byKey(const Key('media-management-duplicate-delete-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-duplicate-delete-dialog-1')),
      findsOneWidget,
    );
    expect(find.textContaining('不再属于重复媒体'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('media-management-duplicate-delete-confirm-button-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(
      find.byKey(const Key('media-management-duplicate-group-1')),
      findsNothing,
    );
    expect(find.text('共 0 组'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows and opens collections for duplicate PornBox media', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 1, items: [_duplicateVideoGroupJson()]),
    );
    int? openedCollectionId;
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      onOpenVideoCollectionDetail: (collectionId) {
        openedCollectionId = collectionId;
      },
    );

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-duplicate-group-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('video-collection-chip-3')), findsOneWidget);
    expect(find.text('系列 A'), findsOneWidget);
    expect(find.text('稍后再看'), findsOneWidget);
    expect(find.text('所属合集'), findsNothing);
    await tester.tap(find.byKey(const Key('video-collection-chip-8')));
    expect(openedCollectionId, 8);
  });

  testWidgets('deletes an invalid media item directly', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _page(total: 1, items: [_invalidMediaJson(1)]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      switchToMaintenance: true,
    );

    expect(find.byKey(const Key('invalid-media-delete-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invalid-media-delete-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-delete-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('invalid-media-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(find.byKey(const Key('invalid-media-row-1')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('batch deletes selected invalid media', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _page(
        total: 2,
        items: [_invalidMediaJson(1), _invalidMediaJson(2)],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 202,
      body: {
        'task_run_id': 7,
        'task_key': 'batch_operation',
        'state': 'pending',
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      switchToMaintenance: true,
    );

    await tester.tap(find.byKey(const Key('invalid-media-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invalid-media-row-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-selection-count')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('invalid-media-batch-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('invalid-media-batch-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    final submit = adapter.requests
        .where((request) => request.path == '/batch-operations')
        .toList();
    expect(submit, hasLength(1));
    expect(submit.single.body, {
      'operation': 'media_delete',
      'ids': [1, 2],
      'delete_files': false,
    });
    expect(adapter.hitCount('DELETE', '/media/1'), 0);
    expect(adapter.hitCount('DELETE', '/media/2'), 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deletes a media item from its card', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(find.byKey(const Key('media-management-delete-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('media-management-delete-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-delete-dialog-1')),
      findsOneWidget,
    );
    expect(find.text('共 1 条 · 已选 1 项'), findsNothing);
    await tester.tap(
      find.byKey(const Key('media-management-delete-confirm-1')),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(find.byKey(const Key('media-management-row-1')), findsNothing);
    expect(find.text('共 0 条'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deleting a PornBox media syncs the deleted video event', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [_duplicateMediaItemJson(1, kind: 'video', videoItemId: 101)],
      ),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    final events = _watchVideoMutationEvents(tester);
    await tester.tap(find.byKey(const Key('media-management-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-delete-confirm-1')),
    );
    await tester.pumpAndSettle();

    expect(events, hasLength(1));
    expect(events.single.kind, VideoMutationKind.deleted);
    expect(events.single.videoId, 101);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('batch delete submits backend task for selected media', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 2,
        items: [
          _duplicateMediaItemJson(1, kind: 'video', videoItemId: 101),
          _duplicateMediaItemJson(2),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 202,
      body: {
        'task_run_id': 7,
        'task_key': 'batch_operation',
        'state': 'pending',
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-batch-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-batch-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    final submit = adapter.requests
        .where((request) => request.path == '/batch-operations')
        .toList();
    expect(submit, hasLength(1));
    expect(submit.single.body, {
      'operation': 'media_delete',
      'ids': [1, 2],
      'delete_files': false,
    });
    expect(adapter.hitCount('DELETE', '/media/1'), 0);
    expect(adapter.hitCount('DELETE', '/media/2'), 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('batch delete submit failure keeps selection and shows toast', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 2,
        items: [_duplicateMediaItemJson(1), _duplicateMediaItemJson(2)],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/batch-operations',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': '服务异常',
        },
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-batch-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-batch-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('服务异常'), findsOneWidget);
    expect(find.text('共 2 条 · 已选 2 项'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('retries a terminal thumbnail from its media card', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(1, thumbnailGenerationState: 'terminal'),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('media-management-retry-thumbnails-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-management-retry-thumbnails-1')),
    );
    await tester.pumpAndSettle();

    final resetRequest = adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/media/thumbnails/reset',
    );
    expect(resetRequest.body, <String, dynamic>{
      'media_ids': <int>[1],
      'force': false,
    });
    expect(find.byKey(const Key('media-management-row-1')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'submits a provider-neutral media transfer from the batch toolbar',
    (tester) async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers/candidates',
        body: <String, dynamic>{
          'source_library': <String, dynamic>{'id': 1, 'name': '媒体库 A'},
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'id': 9, 'name': '媒体库 B'},
          ],
        },
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers',
        statusCode: 202,
        body: <String, dynamic>{
          'task_run_id': 88,
          'task_key': 'media_storage_transfer',
          'state': 'pending',
        },
      );
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        mediaApi: mediaApi,
        apiClient: apiClient,
      );

      await tester.tap(
        find.byKey(const Key('media-management-enter-selection-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-management-row-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('media-management-batch-transfer-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('media-management-transfer-dialog')),
        findsOneWidget,
      );
      expect(find.text('媒体库 B'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('media-management-transfer-confirm-button')),
      );
      await tester.pumpAndSettle();

      final requests = adapter.requests
          .where((request) => request.method == 'POST')
          .toList(growable: false);
      expect(requests[0].path, '/media-transfers/candidates');
      expect(requests[0].body, <String, dynamic>{
        'media_ids': <int>[1],
      });
      expect(requests[1].path, '/media-transfers');
      expect(requests[1].body, <String, dynamic>{
        'media_ids': <int>[1],
        'target_library_id': 9,
      });
      expect(
        find.byKey(const Key('media-management-batch-transfer-button')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('submits a single-item transfer from the row transfer icon', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media-transfers/candidates',
      body: <String, dynamic>{
        'source_library': <String, dynamic>{'id': 1, 'name': '媒体库 A'},
        'targets': <Map<String, dynamic>>[
          <String, dynamic>{'id': 9, 'name': '媒体库 B'},
        ],
      },
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media-transfers',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 88,
        'task_key': 'media_storage_transfer',
        'state': 'pending',
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('media-management-transfer-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-transfer-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-management-transfer-confirm-button')),
    );
    await tester.pumpAndSettle();

    final requests = adapter.requests
        .where((request) => request.method == 'POST')
        .toList(growable: false);
    expect(requests[0].body, <String, dynamic>{
      'media_ids': <int>[1],
    });
    expect(requests[1].body, <String, dynamic>{
      'media_ids': <int>[1],
      'target_library_id': 9,
    });
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('retries selected terminal thumbnails from the filtered list', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(1, thumbnailGenerationState: 'terminal'),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(1, thumbnailGenerationState: 'terminal'),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('media-management-batch-reset-thumbnails-button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('media-management-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-thumbnail-generation-filter-terminal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-filter-trigger')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-batch-reset-thumbnails-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-batch-reset-thumbnails-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const Key('media-management-batch-reset-thumbnails-confirm-button'),
      ),
    );
    await tester.pumpAndSettle();

    final resetRequest = adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/media/thumbnails/reset',
    );
    expect(resetRequest.body, <String, dynamic>{
      'media_ids': <int>[1],
      'force': false,
    });
    expect(find.byKey(const Key('media-management-row-1')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('regenerates selected succeeded thumbnails in force mode', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(1, thumbnailGenerationState: 'succeeded'),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(1, thumbnailGenerationState: 'succeeded'),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('media-management-filter-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-thumbnail-generation-filter-succeeded')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-filter-trigger')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();

    expect(find.text('重新生成缩略图（1）'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('media-management-batch-reset-thumbnails-button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('将删除已选 1 项现有的缩略图'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('media-management-batch-reset-thumbnails-confirm-button'),
      ),
    );
    await tester.pumpAndSettle();

    final resetRequest = adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/media/thumbnails/reset',
    );
    expect(resetRequest.body, <String, dynamic>{
      'media_ids': <int>[1],
      'force': true,
    });
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'regenerates a succeeded thumbnail from its media card after confirmation',
    (tester) async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: _page(
          total: 1,
          items: [
            _duplicateMediaItemJson(1, thumbnailGenerationState: 'succeeded'),
          ],
        ),
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media/thumbnails/reset',
        body: <String, dynamic>{'reset_count': 1},
      );
      adapter.enqueueJson(method: 'GET', path: '/media', body: _emptyPage());
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        mediaApi: mediaApi,
        apiClient: apiClient,
      );

      await tester.tap(
        find.byKey(const Key('media-management-retry-thumbnails-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const Key('media-management-single-regenerate-thumbnails-dialog'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const Key(
            'media-management-single-regenerate-thumbnails-confirm-button',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetRequest = adapter.requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.path == '/media/thumbnails/reset',
      );
      expect(resetRequest.body, <String, dynamic>{
        'media_ids': <int>[1],
        'force': true,
      });
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('enters selection mode from the header button and toggles rows', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('media-management-enter-selection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-select-all-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-search-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-select-all-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-enter-selection-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-refresh-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-batch-delete-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-search-toggle')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();
    expect(find.text('共 1 条 · 已选 1 项'), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-batch-delete-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('media-management-exit-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('共 1 条'), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-enter-selection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-batch-delete-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('media-management-search-toggle')),
      findsOneWidget,
    );
  });

  testWidgets('opens the movie actions dialog from a JAV media row', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
    );
    String? openedMovieNumber;
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      onOpenMovieDetail: (movieNumber) => openedMovieNumber = movieNumber,
    );

    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-row-movie-actions-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-row-movie-actions-play')),
      findsOneWidget,
    );
    expect(find.text('ABC-1'), findsWidgets);
    expect(find.text('共 1 条 · 已选 1 项'), findsNothing);

    await tester.tap(
      find.byKey(const Key('media-row-movie-actions-open-detail')),
    );
    await tester.pumpAndSettle();

    expect(openedMovieNumber, 'ABC-1');
    expect(
      find.byKey(const Key('media-row-movie-actions-dialog')),
      findsNothing,
    );
    expect(find.text('共 1 条 · 已选 1 项'), findsNothing);
  });

  testWidgets('opens the video actions dialog from a PornBox media row', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _page(
        total: 1,
        items: [
          _duplicateMediaItemJson(
            1,
            kind: 'video',
            videoItemId: 101,
            collections: <Map<String, dynamic>>[
              <String, dynamic>{'id': 3, 'name': '系列 A'},
            ],
          ),
        ],
      ),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('media-management-row-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-video-actions-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('desktop-video-action-play')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-video-action-thumbnails')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-video-action-add-to-collection')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('desktop-video-action-delete')), findsNothing);
    expect(find.byKey(const Key('video-collection-chip-3')), findsOneWidget);
    expect(find.text('共 1 条 · 已选 1 项'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required MediaApi mediaApi,
  required ApiClient apiClient,
  bool switchToMaintenance = false,
  void Function(int collectionId)? onOpenVideoCollectionDetail,
  void Function(String movieNumber)? onOpenMovieDetail,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final needsInjectedContent =
      onOpenVideoCollectionDetail != null || onOpenMovieDetail != null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        mediaApiProvider.overrideWithValue(mediaApi),
        batchOperationsApiProvider.overrideWithValue(
          BatchOperationsApi(apiClient: apiClient),
        ),
        mediaLibrariesApiProvider.overrideWithValue(
          _EmptyMediaLibrariesApi(apiClient: apiClient),
        ),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: OKToast(
          child: Scaffold(
            body: !needsInjectedContent
                ? const DesktopMediaManagementPage()
                : MediaManagementContent(
                    keyPrefix: 'media-management',
                    rootKey: const Key('desktop-media-management-page'),
                    onOpenMovieDetail: (_, movieNumber) =>
                        onOpenMovieDetail?.call(movieNumber),
                    onOpenVideoCollectionDetail: (_, collectionId) =>
                        onOpenVideoCollectionDetail?.call(collectionId),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (switchToMaintenance) {
    await tester.tap(find.byKey(const Key('media-management-tab-maintenance')));
    await tester.pumpAndSettle();
  }
}

Future<void> _submitSearch(WidgetTester tester, Key fieldKey) async {
  final field = find.byKey(fieldKey);
  await tester.showKeyboard(field);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

List<VideoMutationChange> _watchVideoMutationEvents(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DesktopMediaManagementPage)),
  );
  final events = <VideoMutationChange>[];
  container.listen(videoMutationEventsProvider, (_, next) {
    final change = next.value;
    if (change != null) events.add(change);
  });
  return events;
}

class _EmptyMediaLibrariesApi extends MediaLibrariesApi {
  const _EmptyMediaLibrariesApi({required super.apiClient});

  @override
  Future<List<MediaLibraryDto>> getLibraries() async =>
      const <MediaLibraryDto>[];
}

Map<String, dynamic> _emptyPage() => _page(total: 0, items: const []);

Map<String, dynamic> _page({required int total, required List items}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 20,
    'total': total,
  };
}

Map<String, dynamic> _invalidMediaJson(int id) {
  return <String, dynamic>{
    'id': id,
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'movie_title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'file_name': 'ABC-$id.mp4',
    'library_id': 1,
    'library_name': 'Main Library',
    'file_size_bytes': 1024,
    'updated_at': '2026-05-13T12:00:00Z',
  };
}

Map<String, dynamic> _duplicateGroupJson() {
  return <String, dynamic>{
    'kind': 'jav',
    'media_count': 2,
    'media_items': [_duplicateMediaItemJson(1), _duplicateMediaItemJson(2)],
  };
}

Map<String, dynamic> _duplicateVideoGroupJson() {
  return <String, dynamic>{
    'kind': 'video',
    'media_count': 2,
    'media_items': [
      _duplicateMediaItemJson(
        1,
        kind: 'video',
        videoItemId: 101,
        collections: <Map<String, dynamic>>[
          <String, dynamic>{'id': 3, 'name': '系列 A'},
          <String, dynamic>{'id': 8, 'name': '稍后再看'},
        ],
      ),
      _duplicateMediaItemJson(2, kind: 'video', videoItemId: 102),
    ],
  };
}

Map<String, dynamic> _duplicateMediaItemJson(
  int id, {
  String kind = 'jav',
  int? videoItemId,
  List<Map<String, dynamic>> collections = const <Map<String, dynamic>>[],
  String thumbnailGenerationState = 'succeeded',
}) {
  return <String, dynamic>{
    'id': id,
    'kind': kind,
    'movie_number': kind == 'jav' ? 'ABC-$id' : null,
    'video_item_id': videoItemId,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main Library',
    'file_name': 'abc-$id.mp4',
    'file_size_bytes': 1024,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': thumbnailGenerationState,
    'thumbnail_last_error_code': null,
    'heat': 100,
    'collections': collections,
    'created_at': '2026-05-13T12:00:00Z',
    'updated_at': '2026-05-13T12:00:00Z',
  };
}
