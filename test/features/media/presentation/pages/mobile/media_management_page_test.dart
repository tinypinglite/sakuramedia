import 'dart:async';

import 'package:dio/dio.dart';
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
import 'package:sakuramedia/features/media/presentation/pages/mobile/media_management_page.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operations_api.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operations_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

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
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders mobile list and supported tabs', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-maintenance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-duplicates')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-batches')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-search-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-search-field')),
      findsNothing,
    );
  });

  testWidgets('expands and searches file name in the compact mobile header', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      theme: sakuraMobileThemeData,
    );

    final searchToggleRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    final filterRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    final sortRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-sort-trigger')),
    );
    final totalRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-total-text')),
    );
    final selectRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-enter-selection-button')),
    );
    final refreshRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-refresh-button')),
    );
    expect(sortRect.left - filterRect.right, closeTo(4, 0.5));
    expect(totalRect.left, greaterThan(sortRect.right));
    expect(selectRect.left, greaterThan(totalRect.right));
    expect(refreshRect.left - selectRect.right, closeTo(4, 0.5));
    expect(searchToggleRect.left - refreshRect.right, closeTo(4, 0.5));
    expect(searchToggleRect.left, greaterThan(refreshRect.right));
    expect(searchToggleRect.center.dy, closeTo(sortRect.center.dy, 0.5));
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
      findsOneWidget,
    );
    expect(find.byTooltip('收起搜索'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-management-total-text')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-sort-trigger')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-enter-selection-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-refresh-button')),
      findsNothing,
    );
    final fieldRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-search-field')),
    );
    expect(fieldRect.height, 40);
    final editableRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('mobile-media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    final searchIconRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('mobile-media-management-search-field')),
        matching: find.byIcon(Icons.search_rounded),
      ),
    );
    final expandedSearchToggleRect = tester.getRect(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    expect(
      tester
          .getRect(
            find.byKey(const Key('mobile-media-management-filter-trigger')),
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
      closeTo(searchToggleRect.center.dx, 0.5),
    );
    expect(expandedSearchToggleRect.left - fieldRect.right, closeTo(8, 0.5));
    final fieldContext = tester.element(
      find.byKey(const Key('mobile-media-management-search-field')),
    );
    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('mobile-media-management-search-field')),
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
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('mobile-media-management-search-field')),
      'abc-1',
    );
    await _submitSearch(
      tester,
      const Key('mobile-media-management-search-field'),
    );
    expect(adapter.requests.last.uri.queryParameters['search'], 'abc-1');

    await tester.tap(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-sort-trigger')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('mobile-media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, 'abc-1');

    await tester.tap(
      find.byKey(const Key('mobile-media-management-search-clear')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.last.uri.queryParameters.containsKey('search'),
      isFalse,
    );
  });

  testWidgets('hides file name search while selecting media', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-search-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('mobile-media-management-search-field')),
      'abc',
    );
    await _submitSearch(
      tester,
      const Key('mobile-media-management-search-field'),
    );

    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-search-toggle')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-exit-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-search-toggle')),
      findsOneWidget,
    );
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('mobile-media-management-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.controller.text, 'abc');
  });

  testWidgets('swiping the content switches tabs', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsOneWidget,
    );
    expect(adapter.hitCount('GET', '/media/duplicates'), 0);

    await tester.drag(
      find.byKey(const Key('mobile-media-management-tab-view')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('GET', '/media/duplicates'), 1);
    expect(
      find.byKey(const Key('mobile-media-management-duplicate-media-section')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('mobile-media-management-tab-view')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsOneWidget,
    );
  });

  testWidgets('long press exposes batch transfer and delete actions', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-batch-transfer-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
      findsNothing,
    );
  });

  testWidgets('select button enters selection mode and toggles rows', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-selection-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-enter-selection-button')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('mobile-media-management-row-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-bottom-selection-count')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-exit-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-enter-selection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsNothing,
    );
  });

  testWidgets('opens the movie actions drawer from a JAV media row', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('mobile-media-management-row-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-row-movie-actions-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-row-movie-actions-play')),
      findsOneWidget,
    );
  });

  testWidgets('opens the video actions sheet from a PornBox media row', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, kind: 'video', videoItemId: 101)],
      ),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('mobile-media-management-row-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-video-actions-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mobile-video-action-play')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-video-action-add-to-collection')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-video-action-delete')), findsNothing);
  });

  testWidgets('deletes a media item from its mobile card', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-row-actions')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-management-row-action-delete')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-delete-dialog-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('media-management-delete-confirm-1')),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('disables the more button of other rows while an action is in flight', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1), _mediaItemJson(2)]),
    );
    adapter.enqueueResponder(
      method: 'DELETE',
      path: '/media/1',
      responder: (options, requestBody) async {
        await deleteCompleter.future;
        return ResponseBody.fromBytes(
          const <int>[],
          204,
          headers: const <String, List<String>>{},
        );
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-row-action-delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-delete-confirm-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
      findsNothing,
      reason: '正在删除的条目：入口换成 loading',
    );
    expect(
      tester
          .widget<AppInteractiveSurface>(
            find.byKey(const Key('mobile-media-management-row-actions-2')),
          )
          .enabled,
      isFalse,
      reason: '删除在途时其它条目的「更多」入口应禁用，避免开出所有动作都点不动的操作表',
    );

    deleteCompleter.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows labeled management actions in the row more sheet', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'terminal')],
      ),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-row-actions')),
      findsOneWidget,
    );
    expect(find.text('ABC-1'), findsWidgets);
    expect(find.text('重试缩略图'), findsOneWidget);
    expect(find.text('迁移'), findsOneWidget);
    expect(find.text('删除媒体'), findsOneWidget);
    expect(find.text('删除该媒体及其文件，不可恢复'), findsOneWidget);
  });

  testWidgets('retries a terminal thumbnail from its mobile card', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'terminal')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-row-actions-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-management-row-action-retry-thumbnails')),
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
    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('invalid media reuses the mobile media card', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: <String, dynamic>{
        'items': [_invalidMediaJson(1)],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-tab-maintenance')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invalid-media-row-1')), findsOneWidget);
    expect(
      find.byKey(const Key('invalid-media-row-heading-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invalid-media-delete-1')), findsOneWidget);
  });

  testWidgets('batch deletes selected invalid media on mobile', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: <String, dynamic>{
        'items': [_invalidMediaJson(1), _invalidMediaJson(2)],
        'page': 1,
        'page_size': 20,
        'total': 2,
      },
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
      find.byKey(const Key('mobile-media-management-tab-maintenance')),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('invalid-media-row-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invalid-media-row-2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-batch-delete-button')),
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

  testWidgets('mobile filter opens bottom drawer', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-filter-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('缩略图状态'), findsOneWidget);
  });

  testWidgets('retries selected terminal thumbnails from mobile actions', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'terminal')],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'terminal')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-thumbnail-generation-filter-terminal')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('mobile-media-management-batch-reset-thumbnails-button'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const Key('mobile-media-management-batch-reset-thumbnails-button'),
      ),
    );
    await tester.pumpAndSettle();
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
    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('regenerates selected succeeded thumbnails on mobile', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'succeeded')],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(
        items: [_mediaItemJson(1, thumbnailGenerationState: 'succeeded')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/thumbnails/reset',
      body: <String, dynamic>{'reset_count': 1},
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-thumbnail-generation-filter-succeeded')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('重新生成'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('mobile-media-management-batch-reset-thumbnails-button'),
      ),
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
    'regenerates a succeeded thumbnail from its mobile card after confirmation',
    (tester) async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: _mediaPage(
          items: [_mediaItemJson(1, thumbnailGenerationState: 'succeeded')],
        ),
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media/thumbnails/reset',
        body: <String, dynamic>{'reset_count': 1},
      );
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: _mediaPage(items: const []),
      );
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        mediaApi: mediaApi,
        apiClient: apiClient,
      );

      await tester.tap(
        find.byKey(const Key('mobile-media-management-row-actions-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('media-management-row-action-retry-thumbnails')),
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
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required MediaApi mediaApi,
  required ApiClient apiClient,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        theme: theme ?? sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: const OKToast(child: Scaffold(body: MobileMediaManagementPage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitSearch(WidgetTester tester, Key fieldKey) async {
  final field = find.byKey(fieldKey);
  await tester.showKeyboard(field);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

class _EmptyMediaLibrariesApi extends MediaLibrariesApi {
  const _EmptyMediaLibrariesApi({required super.apiClient});

  @override
  Future<List<MediaLibraryDto>> getLibraries() async =>
      const <MediaLibraryDto>[];
}

Map<String, dynamic> _mediaPage({required List<Map<String, dynamic>> items}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 30,
    'total': items.length,
  };
}

Map<String, dynamic> _mediaItemJson(
  int id, {
  String thumbnailGenerationState = 'succeeded',
  String kind = 'jav',
  int? videoItemId,
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
    'library_name': 'Main',
    'file_name': 'abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': thumbnailGenerationState,
    'thumbnail_last_error_code': null,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
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
