import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local library keeps filesystem browsing and auto mode', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_localLibrary()]);
    _enqueueLocalDirectory(bundle);

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    expect(find.text('本地库 · 本地存储'), findsOneWidget);
    expect(find.text('自动选择（保留源文件）'), findsOneWidget);
    expect(find.text('/mnt/incoming'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('media-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('result:local:/mnt/incoming:auto'), findsOneWidget);
  });

  testWidgets('cloud115 root and management directory cannot be selected', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_cloudLibrary()]);
    _enqueueCloudDirectory(
      bundle,
      cid: '0',
      entries: <Map<String, dynamic>>[
        _cloudEntry(id: 'cid-root', name: 'sakuramedia', isDirectory: true),
        _cloudEntry(id: 'cid-source', name: '来源目录', isDirectory: true),
        _cloudEntry(id: 'file-1', name: 'ABP-123.mp4', size: 1024),
      ],
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    expect(
      find.byKey(const Key('media-import-cloud-root-hint')),
      findsOneWidget,
    );
    expect(find.text('导入后清理源文件'), findsOneWidget);
    expect(find.text('媒体库管理目录，不可选择'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('media-import-picker-submit-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const Key('media-import-cloud-entry-cid-root')),
    );
    await tester.pump();
    expect(
      bundle.adapter.hitCount('GET', '/media-libraries/cloud115/2/entries'),
      1,
    );

    _enqueueCloudDirectory(bundle, cid: 'cid-source');
    await tester.tap(
      find.byKey(const Key('media-import-cloud-entry-cid-source')),
    );
    await tester.pumpAndSettle();

    expect(find.text('115 网盘 / 来源目录'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const Key('media-import-picker-submit-button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(
      find.byKey(const Key('media-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('result:cloud115:cid-source:cleanup-source'), findsOneWidget);
  });

  testWidgets('cloud115 supports pagination and cleanup warning', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_cloudLibrary()]);
    _enqueueCloudDirectory(
      bundle,
      cid: '0',
      total: 2,
      entries: <Map<String, dynamic>>[
        _cloudEntry(id: 'cid-source', name: '来源目录', isDirectory: true),
      ],
    );
    _enqueueCloudDirectory(
      bundle,
      cid: '0',
      offset: 1,
      total: 2,
      entries: <Map<String, dynamic>>[
        _cloudEntry(id: 'cid-more', name: '更多目录', isDirectory: true),
      ],
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    await tester.tap(
      find.byKey(const Key('media-import-cloud-load-more-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-import-cloud-entry-cid-more')),
      findsOneWidget,
    );
    final loadMoreRequest = bundle.adapter.requests.last;
    expect(loadMoreRequest.uri.queryParameters['offset'], '1');

    await tester.tap(find.text('导入后清理源文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入后清理源文件').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-import-cloud-cleanup-warning')),
      findsOneWidget,
    );
    expect(find.text('导入并删除源文件'), findsOneWidget);
  });

  testWidgets('cloud115 auth failure points user to media library settings', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_cloudLibrary()]);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries/cloud115/2/entries',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'cloud115_cookies_invalid',
          'message': 'cookies expired',
        },
      },
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    expect(find.text('115 登录已失效，请前往“系统设置 → 媒体库”重新认证后重试。'), findsOneWidget);
  });

  testWidgets('switching library ignores an in-flight old browse response', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[
      _localLibrary(),
      _cloudLibrary(),
    ]);
    final delayedLocal = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/filesystem/entries',
      responder: (_, __) => delayedLocal.future,
    );
    _enqueueCloudDirectory(
      bundle,
      cid: '0',
      entries: <Map<String, dynamic>>[
        _cloudEntry(id: 'cid-source', name: '来源目录', isDirectory: true),
      ],
    );

    await _pumpHarness(tester, bundle);
    await tester.tap(find.byKey(const Key('launch-directory-picker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('本地库 · 本地存储'));
    await tester.pump();
    await tester.tap(find.text('115 库 · 115 网盘').last);
    await tester.pump();
    await tester.pumpAndSettle();

    delayedLocal.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'path': '/stale/local',
          'parent': null,
          'entries': <Map<String, dynamic>>[],
        }),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('115 网盘'), findsOneWidget);
    expect(
      find.byKey(const Key('media-import-cloud-entry-cid-source')),
      findsOneWidget,
    );
    expect(find.text('/stale/local'), findsNothing);
  });
}

Future<TestApiBundle> _buildBundle() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
  );
  return createTestApiBundle(sessionStore);
}

Future<void> _pumpHarness(WidgetTester tester, TestApiBundle bundle) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: _PickerHarness()),
      ),
    ),
  );
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('launch-directory-picker')));
  await tester.pumpAndSettle();
}

void _enqueueLibraries(
  TestApiBundle bundle,
  List<Map<String, dynamic>> libraries,
) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
  );
}

void _enqueueLocalDirectory(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/filesystem/entries',
    body: <String, dynamic>{
      'path': '/mnt/incoming',
      'parent': '/mnt',
      'entries': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'movies',
          'path': '/mnt/incoming/movies',
          'type': 'dir',
          'size': 0,
          'is_video': false,
        },
      ],
    },
  );
}

void _enqueueCloudDirectory(
  TestApiBundle bundle, {
  required String cid,
  int offset = 0,
  int? total,
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[],
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries/cloud115/2/entries',
    body: <String, dynamic>{
      'cid': cid,
      'total': total ?? entries.length,
      'offset': offset,
      'limit': 200,
      'root_cid': 'cid-root',
      'entries': entries,
    },
  );
}

Map<String, dynamic> _localLibrary() => <String, dynamic>{
  'id': 1,
  'name': '本地库',
  'backend': 'local',
  'backend_config': <String, dynamic>{'root_path': '/media'},
  'created_at': '2026-07-14T09:00:00Z',
  'updated_at': '2026-07-14T09:00:00Z',
};

Map<String, dynamic> _cloudLibrary() => <String, dynamic>{
  'id': 2,
  'name': '115 库',
  'backend': 'cloud115',
  'backend_config': <String, dynamic>{
    'root_cid': 'cid-root',
    'app': 'alipaymini',
  },
  'created_at': '2026-07-14T09:00:00Z',
  'updated_at': '2026-07-14T09:00:00Z',
};

Map<String, dynamic> _cloudEntry({
  required String id,
  required String name,
  bool isDirectory = false,
  int size = 0,
}) => <String, dynamic>{
  'entry_id': id,
  'name': name,
  'is_dir': isDirectory,
  'size': size,
  'is_video': !isDirectory,
  'mtime': 1700000000,
};

class _PickerHarness extends StatefulWidget {
  const _PickerHarness();

  @override
  State<_PickerHarness> createState() => _PickerHarnessState();
}

class _PickerHarnessState extends State<_PickerHarness> {
  String? _result;

  Future<void> _open() async {
    final request = await showDirectoryPickerDialog(context);
    if (!mounted || request == null) {
      return;
    }
    final sourceText = switch (request.source) {
      LocalMediaImportSource(:final path) => 'local:$path',
      Cloud115MediaImportSource(:final cid) => 'cloud115:$cid',
      Cloud115FileMediaImportSource(:final fid) => 'cloud115-file:$fid',
    };
    setState(() {
      _result = 'result:$sourceText:${request.transferMode.wireValue}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            key: const Key('launch-directory-picker'),
            label: '打开',
            onPressed: () => unawaited(_open()),
          ),
          if (_result != null) Text(_result!),
        ],
      ),
    );
  }
}
