import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/manual_download_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingFilePicker picker;
  late FilePickerPlatform originalPicker;

  setUp(() {
    picker = _RecordingFilePicker();
    originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
  });

  testWidgets('validates, shows PornBox, and exposes collection creation', (
    tester,
  ) async {
    await _openDialog(tester);

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('请粘贴下载链接'), findsOneWidget);
    expect(find.text('请填写番号'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'not-a-download-link',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('无法识别该链接，请检查磁力、eD2k 或 HTTP/HTTPS 地址'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('manual-download-kind-video')),
    );
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    expect(find.text('PornBox'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-movie-number-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('manual-download-collection-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-create-collection-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows source modes supported by the selected client', (
    tester,
  ) async {
    await _openDialog(
      tester,
      clients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'qb-main',
          'library_id': 1,
          'supported_source_kinds': <String>['magnet', 'torrent'],
        },
        <String, dynamic>{
          'id': 2,
          'name': '115-main',
          'library_id': 2,
          'supported_source_kinds': <String>[
            'magnet',
            'torrent',
            'ed2k',
            'http',
          ],
        },
      ],
    );

    expect(
      find.byKey(const Key('manual-download-source-mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-source-mode-link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-source-mode-torrent')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manual-download-link-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-download-client-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('115-main').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('manual-download-source-mode')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manual-download-link-field')), findsOneWidget);
  });

  testWidgets('does not report unsupported source while clients are loading', (
    tester,
  ) async {
    final clientsGate = Completer<void>();
    await _openDialog(tester, clientsGate: clientsGate, settleAfterOpen: false);

    expect(find.text('正在加载下载器…'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-source-unsupported')),
      findsNothing,
    );

    clientsGate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-link-field')), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-source-unsupported')),
      findsNothing,
    );
  });

  testWidgets('does not report unsupported source when clients fail', (
    tester,
  ) async {
    await _openDialog(tester, clientsStatusCode: 500);

    expect(
      find.byKey(const Key('manual-download-clients-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-source-unsupported')),
      findsNothing,
    );
  });

  testWidgets('does not report unsupported source when no clients exist', (
    tester,
  ) async {
    await _openDialog(tester, clients: const <Map<String, dynamic>>[]);

    expect(find.byKey(const Key('manual-download-no-clients')), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-source-unsupported')),
      findsNothing,
    );
  });

  testWidgets('disables submit when detected link kind is unsupported', (
    tester,
  ) async {
    final bundle = await _openDialog(tester);

    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'https://cdn.example/movie.mp4',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('manual-download-detected-source-kind')),
      findsOneWidget,
    );
    expect(find.text('HTTP 直链'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-source-selected-unsupported')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('manual-download-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(bundle.adapter.hitCount('POST', '/download-requests/manual'), 0);
  });

  testWidgets('switches to torrent when the new client only supports torrent', (
    tester,
  ) async {
    await _openDialog(
      tester,
      clients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'qb-main',
          'library_id': 1,
          'supported_source_kinds': <String>['magnet', 'torrent'],
        },
        <String, dynamic>{
          'id': 2,
          'name': 'torrent-only',
          'library_id': 2,
          'supported_source_kinds': <String>['torrent'],
        },
      ],
    );

    await tester.tap(find.byKey(const Key('manual-download-client-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('torrent-only').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-source-mode')), findsNothing);
    expect(find.byKey(const Key('manual-download-link-field')), findsNothing);
    expect(
      find.byKey(const Key('manual-download-pick-torrent-button')),
      findsOneWidget,
    );
  });

  testWidgets('hides source mode switch when only torrent is available', (
    tester,
  ) async {
    await _openDialog(
      tester,
      clients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'torrent-only',
          'library_id': 1,
          'supported_source_kinds': <String>['torrent'],
        },
      ],
    );

    expect(find.byKey(const Key('manual-download-source-mode')), findsNothing);
    expect(find.byKey(const Key('manual-download-link-field')), findsNothing);
    expect(
      find.byKey(const Key('manual-download-pick-torrent-button')),
      findsOneWidget,
    );
  });

  testWidgets('keeps source area height stable across modes', (tester) async {
    await _openDialog(tester);

    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.pumpAndSettle();
    final linkHeight = tester
        .getSize(find.byKey(const Key('manual-download-link-field')))
        .height;
    final modeRect = tester.getRect(
      find.byKey(const Key('manual-download-source-mode')),
    );
    final nextRowTop = tester
        .getTopLeft(find.byKey(const Key('manual-download-kind-jav')))
        .dy;
    await tester.tap(
      find.byKey(const Key('manual-download-source-mode-torrent')),
    );
    await tester.pumpAndSettle();
    final torrentHeight = tester
        .getSize(find.byKey(const Key('manual-download-torrent-dropzone')))
        .height;

    expect(torrentHeight, linkHeight);
    expect(
      tester.getRect(find.byKey(const Key('manual-download-source-mode'))),
      modeRect,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('manual-download-kind-jav'))).dy,
      nextRowTop,
    );
  });

  testWidgets('keeps source area height stable across modes on mobile', (
    tester,
  ) async {
    await _openDialog(
      tester,
      platform: AppPlatform.mobile,
      size: const Size(390, 844),
    );

    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.pumpAndSettle();
    final linkHeight = tester
        .getSize(find.byKey(const Key('manual-download-link-field')))
        .height;
    final modeRect = tester.getRect(
      find.byKey(const Key('manual-download-source-mode')),
    );
    final nextRowTop = tester
        .getTopLeft(find.byKey(const Key('manual-download-kind-jav')))
        .dy;
    await tester.tap(
      find.byKey(const Key('manual-download-source-mode-torrent')),
    );
    await tester.pumpAndSettle();
    final torrentHeight = tester
        .getSize(find.byKey(const Key('manual-download-torrent-dropzone')))
        .height;

    expect(torrentHeight, linkHeight);
    expect(
      tester.getRect(find.byKey(const Key('manual-download-source-mode'))),
      modeRect,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('manual-download-kind-jav'))).dy,
      nextRowTop,
    );
  });

  testWidgets('submits eD2k source kind', (tester) async {
    final bundle = await _openDialog(
      tester,
      clients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '115-main',
          'library_id': 1,
          'supported_source_kinds': <String>[
            'magnet',
            'torrent',
            'ed2k',
            'http',
          ],
        },
      ],
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'ed2k://|file|movie.mp4|12345|0123456789abcdef0123456789abcdef|/',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('manual-download-detected-source-kind')),
      findsOneWidget,
    );
    expect(find.text('eD2k 链接'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('manual-download-kind-video')),
    );
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(movieNumber: null, mediaKind: 'video'),
    );
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('manual-download-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(
      find.byKey(const Key('manual-download-submit-button')),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('无法识别该链接，请检查磁力、eD2k 或 HTTP/HTTPS 地址'), findsNothing);
    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body['source_kind'], 'ed2k');
    expect(
      request.body['source_uri'],
      'ed2k://|file|movie.mp4|12345|0123456789abcdef0123456789abcdef|/',
    );
  });

  testWidgets('submits HTTP direct source kind', (tester) async {
    final bundle = await _openDialog(
      tester,
      clients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'guangya-main',
          'library_id': 1,
          'supported_source_kinds': <String>[
            'magnet',
            'torrent',
            'ed2k',
            'http',
          ],
        },
      ],
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'https://cdn.example/movie.mp4?token=secret',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('manual-download-detected-source-kind')),
      findsOneWidget,
    );
    expect(find.text('HTTP 直链'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('manual-download-kind-video')),
    );
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(movieNumber: null, mediaKind: 'video'),
    );
    await tester.ensureVisible(
      find.byKey(const Key('manual-download-submit-button')),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body['source_kind'], 'http');
    expect(
      request.body['source_uri'],
      'https://cdn.example/movie.mp4?token=secret',
    );
  });

  testWidgets('prefilled dialog skips movie query and submits compact form', (
    tester,
  ) async {
    const hash = '0123456789abcdef0123456789abcdef01234567';
    final bundle = await _openDialog(
      tester,
      prefill: const ManualDownloadPrefill(
        sourceUri: 'magnet:?xt=urn:btih:$hash',
        movieNumber: 'ABC-001',
        movieTitle: 'Prefilled Movie',
        movieCoverUrl: '',
      ),
    );

    expect(find.text('添加下载'), findsOneWidget);
    expect(find.text('链接已从评论填入，确认下载器后提交。'), findsOneWidget);
    expect(find.text('magnet:?xt=urn:btih:$hash'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );
    expect(find.text('当前影片'), findsOneWidget);
    expect(find.text('Prefilled Movie'), findsOneWidget);
    expect(find.byKey(const Key('manual-download-kind-jav')), findsNothing);
    expect(
      find.byKey(const Key('manual-download-movie-number-field')),
      findsNothing,
    );
    // 紧凑弹窗只有来源、影片和下载器三项，不再渲染分组标题和下载器字段名。
    expect(find.text('资源'), findsNothing);
    expect(find.text('下载设置'), findsNothing);
    expect(find.text('下载器'), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-modal')), findsNothing);
    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body, {
      'client_id': 1,
      'media_kind': 'jav',
      'source_uri': 'magnet:?xt=urn:btih:$hash',
      'source_kind': 'magnet',
      'movie_number': 'ABC-001',
      'delete_source_after_import': false,
    });
  });

  testWidgets('prefilled dialog opens compact on mobile without overflow', (
    tester,
  ) async {
    const hash = '0123456789abcdef0123456789abcdef01234567';
    await _openDialog(
      tester,
      platform: AppPlatform.mobile,
      size: const Size(390, 844),
      prefill: const ManualDownloadPrefill(
        sourceUri: 'magnet:?xt=urn:btih:$hash',
        movieNumber: 'ABC-001',
        movieTitle: 'Prefilled Movie',
      ),
    );

    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);
    expect(find.text('添加下载'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-movie-number-field')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits jav magnet after resolving a local movie', (
    tester,
  ) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    _enqueueParsed(bundle, query: 'ABC-001', movieNumber: 'ABC-001');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'ABC-001', title: 'Movie'),
    ]);
    await _tapQuery(tester);

    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );
    expect(find.text('Movie'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-modal')), findsNothing);
    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body, {
      'client_id': 1,
      'media_kind': 'jav',
      'source_uri':
          'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
      'source_kind': 'magnet',
      'movie_number': 'ABC-001',
      'delete_source_after_import': false,
    });
    final host = tester.state<_DialogHostState>(find.byType(_DialogHost));
    expect(host.result, isNotNull);
    expect(host.result!.response.created, isTrue);
    expect(host.result!.clientName, 'qb-main');
  });

  testWidgets('submits stored canonical number for a local hit', (
    tester,
  ) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ssni888',
    );
    _enqueueParsed(bundle, query: 'ssni888', movieNumber: 'SSNI-888');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'SNI-888', title: 'Decoy'),
      _movieJson(movieNumber: 'ssni_888', title: 'Local Movie'),
    ]);
    await _tapQuery(tester);

    expect(find.text('Local Movie'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(movieNumber: 'ssni_888'),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body['movie_number'], 'ssni_888');
  });

  testWidgets('falls back online when local has no exact match', (
    tester,
  ) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'abp123',
    );
    _enqueueParsed(bundle, query: 'abp123', movieNumber: 'ABP-123');
    _enqueueLocalMovies(bundle, const <Map<String, dynamic>>[]);
    _enqueueOnlineCompleted(
      bundle,
      movieNumber: 'ABP-123',
      title: 'Online Movie',
    );
    await _tapQuery(tester);

    expect(find.text('Online Movie'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/movies/metadata-imports'), 1);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(movieNumber: 'ABP-123'),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body['movie_number'], 'ABP-123');
  });

  testWidgets('blocks submit when local and online both miss', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'abc999',
    );
    _enqueueParsed(bundle, query: 'abc999', movieNumber: 'ABC-999');
    _enqueueLocalMovies(bundle, const <Map<String, dynamic>>[]);
    _enqueueOnlineNotFound(bundle);
    await _tapQuery(tester);

    expect(
      find.byKey(const Key('manual-download-movie-resolution-error')),
      findsOneWidget,
    );
    expect(find.text('本地和在线均未找到 ABC-999'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('POST', '/download-requests/manual'), 0);
    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);
  });

  testWidgets('parse failure skips local and online search', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'hello',
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      body: <String, dynamic>{
        'query': 'hello',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );
    await _tapQuery(tester);

    expect(find.text('无法识别番号，请输入完整番号（如 SSNI-888）'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/movies'), 0);
    expect(bundle.adapter.hitCount('POST', '/movies/metadata-imports'), 0);
  });

  testWidgets('editing the number clears the resolved movie', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    _enqueueParsed(bundle, query: 'ABC-001', movieNumber: 'ABC-001');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'ABC-001', title: 'Movie'),
    ]);
    await _tapQuery(tester);
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-002',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('请先点击「查询」并匹配影片'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/download-requests/manual'), 0);
  });

  testWidgets('enter key triggers the number query', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    _enqueueParsed(bundle, query: 'ABC-001', movieNumber: 'ABC-001');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'ABC-001', title: 'Movie'),
    ]);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/movies/search/parse-number'), 1);
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );
  });

  testWidgets('creates a PornBox collection and submits its id', (
    tester,
  ) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('manual-download-create-collection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('video-collection-name-field')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('video-collection-name-field')),
      'New Collection',
    );
    const created = <String, dynamic>{
      'id': 9,
      'name': 'New Collection',
      'item_count': 0,
    };
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections',
      statusCode: 201,
      body: created,
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/video-collections',
      body: const <Map<String, dynamic>>[created],
    );
    await tester.tap(find.byKey(const Key('video-collection-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('New Collection'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 201,
      body: _manualTaskJson(
        movieNumber: null,
        mediaKind: 'video',
        collectionId: 9,
      ),
    );
    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.path == '/download-requests/manual',
    );
    expect(request.body['media_kind'], 'video');
    expect(request.body['collection_id'], 9);
    expect(request.body.containsKey('movie_number'), isFalse);
  });

  testWidgets('keeps dialog open and shows backend error', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    _enqueueParsed(bundle, query: 'ABC-001', movieNumber: 'ABC-001');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'ABC-001', title: 'Movie'),
    ]);
    await _tapQuery(tester);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-requests/manual',
      statusCode: 409,
      body: {
        'error': {
          'code': 'download_task_already_imported',
          'message': '该资源已有下载任务且已进入导入流程',
        },
      },
    );

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-submit-error')),
      findsOneWidget,
    );
    expect(find.text('该资源已有下载任务且已进入导入流程'), findsOneWidget);
  });

  testWidgets('提交中不能用关闭按钮或遮罩关闭弹窗', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('manual-download-link-field')),
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
    );
    final gate = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/download-requests/manual',
      responder: (options, body) async {
        await gate.future;
        return ResponseBody.fromString(
          jsonEncode(_manualTaskJson()),
          201,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pump();
    final closeButton = tester.widget<AppInteractiveSurface>(
      find.byKey(const Key('manual-download-close-button')),
    );
    expect(closeButton.enabled, isFalse);

    await tester.tap(find.byKey(const Key('manual-download-close-button')));
    await tester.pump();
    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);

    // 点遮罩同样不能关闭：PopScope 会拦住 maybePop。
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-download-modal')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('opens as bottom drawer on mobile without overflow', (
    tester,
  ) async {
    final bundle = await _openDialog(
      tester,
      platform: AppPlatform.mobile,
      size: const Size(390, 844),
    );
    expect(find.byKey(const Key('manual-download-modal')), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-source-mode')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manual-download-link-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const Key('manual-download-movie-number-field')),
      'ABC-001',
    );
    _enqueueParsed(bundle, query: 'ABC-001', movieNumber: 'ABC-001');
    _enqueueLocalMovies(bundle, <Map<String, dynamic>>[
      _movieJson(movieNumber: 'ABC-001', title: 'Movie'),
    ]);
    await _tapQuery(tester);
    expect(
      find.byKey(const Key('manual-download-movie-resolution-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    expect(find.text('PornBox'), findsOneWidget);
    expect(
      find.byKey(const Key('manual-download-collection-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('manual-download-create-collection-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects oversized torrent file before posting', (tester) async {
    final bundle = await _openDialog(tester);
    await tester.tap(
      find.byKey(const Key('manual-download-source-mode-torrent')),
    );
    await tester.pumpAndSettle();
    // PornBox 不需要番号解析，直接验证文件大小门禁。
    await tester.tap(find.byKey(const Key('manual-download-kind-video')));
    await tester.pumpAndSettle();
    final oversized = _SelectedFile(
      name: 'big.torrent',
      bytes: Uint8List(DownloadsApi.maxManualTorrentBytes + 1),
    );
    picker.selectedFile = oversized;

    await tester.tap(
      find.byKey(const Key('manual-download-pick-torrent-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('种子文件不能超过 10 MB'), findsOneWidget);
    expect(oversized.readCount, 0, reason: '超限文件不应被整体读入内存');

    await tester.tap(find.byKey(const Key('manual-download-submit-button')));
    await tester.pumpAndSettle();
    expect(
      bundle.adapter.hitCount('POST', '/download-requests/manual/torrent'),
      0,
    );
  });
}

Future<TestApiBundle> _openDialog(
  WidgetTester tester, {
  AppPlatform platform = AppPlatform.desktop,
  Size size = const Size(1200, 900),
  ManualDownloadPrefill? prefill,
  List<Map<String, dynamic>>? clients,
  int clientsStatusCode = 200,
  Completer<void>? clientsGate,
  bool settleAfterOpen = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
  );
  final bundle = await createTestApiBundle(sessionStore);
  addTearDown(bundle.dispose);
  addTearDown(sessionStore.dispose);
  final clientBody =
      clients ??
      const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'qb-main',
          'library_id': 1,
          'supported_source_kinds': <String>['magnet', 'torrent'],
        },
      ];
  if (clientsGate == null) {
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/download-clients',
      statusCode: clientsStatusCode,
      body: clientBody,
    );
  } else {
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/download-clients',
      responder: (_, _) async {
        await clientsGate.future;
        return ResponseBody.fromString(
          jsonEncode(clientBody),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );
  }
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/video-collections',
    body: const <Map<String, dynamic>>[],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: platform == AppPlatform.mobile
            ? sakuraMobileThemeData
            : sakuraDesktopThemeData,
        home: AppPlatformScope(
          platform: platform,
          child: OKToast(child: _DialogHost(prefill: prefill)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-manual-download')));
  if (settleAfterOpen) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return bundle;
}

Future<void> _tapQuery(WidgetTester tester) async {
  // enterText 后的 setState 需要先出一帧，查询按钮才会拿到非空 onPressed。
  await tester.pump();
  await tester.tap(
    find.byKey(const Key('manual-download-movie-number-query-button')),
  );
  await tester.pumpAndSettle();
}

void _enqueueParsed(
  TestApiBundle bundle, {
  required String query,
  required String movieNumber,
}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/movies/search/parse-number',
    body: <String, dynamic>{
      'query': query,
      'parsed': true,
      'movie_number': movieNumber,
      'reason': null,
    },
  );
}

void _enqueueLocalMovies(
  TestApiBundle bundle,
  List<Map<String, dynamic>> movies,
) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies',
    body: <String, dynamic>{
      'items': movies,
      'page': 1,
      'page_size': 50,
      'total': movies.length,
    },
  );
}

void _enqueueOnlineCompleted(
  TestApiBundle bundle, {
  required String movieNumber,
  required String title,
}) {
  final movie = jsonEncode(_movieJson(movieNumber: movieNumber, title: title));
  bundle.adapter.enqueueSse(
    method: 'POST',
    path: '/movies/metadata-imports',
    chunks: <String>[
      'event: search_started\n'
          'data: {"movie_number":"$movieNumber"}\n\n',
      'event: completed\n'
          'data: {"success":true,"movies":[$movie],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
    ],
  );
}

void _enqueueOnlineNotFound(TestApiBundle bundle) {
  bundle.adapter.enqueueSse(
    method: 'POST',
    path: '/movies/metadata-imports',
    chunks: <String>[
      'event: completed\n'
          'data: {"success":false,"reason":"movie_not_found","movies":[]}\n\n',
    ],
  );
}

Map<String, dynamic> _movieJson({
  required String movieNumber,
  required String title,
}) => <String, dynamic>{
  'id': 1,
  'movie_number': movieNumber,
  'title': title,
  'is_subscribed': false,
  'can_play': false,
};

Map<String, dynamic> _manualTaskJson({
  int id = 500,
  String? movieNumber = 'ABC-001',
  int? collectionId,
  String mediaKind = 'jav',
}) => <String, dynamic>{
  'task': <String, dynamic>{
    'id': id,
    'client_id': 1,
    'movie_number': movieNumber,
    'media_kind': mediaKind,
    'collection_id': collectionId,
    'name': movieNumber ?? 'manual',
    'remote_id': 'remote-$id',
    'state': 'queued',
    'progress': 0.0,
    'import_status': 'pending',
    'created_at': '2026-08-10T12:00:00Z',
    'updated_at': '2026-08-10T12:00:00Z',
  },
  'created': true,
};

class _DialogHost extends StatefulWidget {
  const _DialogHost({this.prefill});

  final ManualDownloadPrefill? prefill;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  ManualDownloadResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AppButton(
          key: const Key('open-manual-download'),
          label: '打开',
          onPressed: () async {
            final next = await showManualDownloadDialog(
              context,
              prefill: widget.prefill,
            );
            if (mounted) {
              setState(() => result = next);
            }
          },
        ),
      ),
    );
  }
}

class _RecordingFilePicker extends FilePickerPlatform {
  PlatformFile? selectedFile;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return selectedFile;
  }
}

final class _SelectedFile extends PlatformFile {
  _SelectedFile({required this.name, this.bytes});

  @override
  final String name;

  final Uint8List? bytes;

  int readCount = 0;

  @override
  int? lengthSync() => bytes?.length;

  @override
  Future<int?> length() async => bytes?.length;

  @override
  Future<Uint8List> readAsBytes() async {
    readCount++;
    if (bytes == null) throw StateError('Cannot read selected file');
    return bytes!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
