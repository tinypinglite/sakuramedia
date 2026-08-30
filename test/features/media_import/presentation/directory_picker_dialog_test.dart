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

  testWidgets('browses provider sources and selects an opaque directory', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_library()]);
    _enqueueBrowse(
      bundle,
      libraryId: 1,
      entries: <Map<String, dynamic>>[
        _entry(ref: 'folder-1', name: 'Movies', type: 'directory'),
        _entry(ref: 'file-1', name: 'movie.mkv', type: 'file', isVideo: true),
      ],
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    expect(find.text('主媒体库 · provider-a'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('保留源文件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-import-entry-0')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('media-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('result:{"id":"folder-1"}:keep'), findsOneWidget);
  });

  testWidgets('opens directories and uses cursor pagination', (tester) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[_library()]);
    _enqueueBrowse(
      bundle,
      libraryId: 1,
      entries: <Map<String, dynamic>>[
        _entry(ref: 'folder-1', name: 'Movies', type: 'directory'),
      ],
    );
    _enqueueBrowse(
      bundle,
      libraryId: 1,
      parentRef: <String, dynamic>{'id': 'folder-1'},
      nextCursor: 'next',
      entries: <Map<String, dynamic>>[
        _entry(ref: 'file-1', name: 'a.mkv', type: 'file', isVideo: true),
      ],
    );
    _enqueueBrowse(
      bundle,
      libraryId: 1,
      parentRef: <String, dynamic>{'id': 'folder-1'},
      cursor: 'next',
      entries: <Map<String, dynamic>>[
        _entry(ref: 'file-2', name: 'b.mkv', type: 'file', isVideo: true),
      ],
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('media-import-entry-open-Movies')));
    await tester.pumpAndSettle();

    expect(find.text('Movies'), findsWidgets);
    expect(
      find.byKey(const Key('media-import-picker-load-more-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-import-picker-load-more-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('b.mkv'), findsOneWidget);
    final browseRequest = bundle.adapter.requests.last;
    expect(browseRequest.body, <String, dynamic>{
      'library_id': 1,
      'parent_ref': <String, dynamic>{'id': 'folder-1'},
      'cursor': 'next',
      'limit': 50,
    });
  });

  testWidgets('stale browse response cannot replace a newly selected library', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[
      _library(),
      _otherLibrary(),
    ]);
    final delayedBrowse = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/import-sources/browse',
      responder: (_, __) => delayedBrowse.future,
    );
    _enqueueBrowse(
      bundle,
      libraryId: 2,
      entries: <Map<String, dynamic>>[
        _entry(ref: 'other-root', name: 'Other', type: 'directory'),
      ],
    );

    await _pumpHarness(tester, bundle);
    await tester.tap(find.byKey(const Key('launch-directory-picker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('media-import-library-select')));
    await tester.pump();
    await tester.tap(find.text('其他媒体库 · provider-b').last);
    await tester.pumpAndSettle();

    delayedBrowse.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'library_id': 1,
          'entries': <Map<String, dynamic>>[
            _entry(ref: 'stale', name: 'Stale', type: 'directory'),
          ],
          'next_cursor': null,
        }),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Stale'), findsNothing);
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

void _enqueueBrowse(
  TestApiBundle bundle, {
  required int libraryId,
  Map<String, dynamic>? parentRef,
  String? cursor,
  String? nextCursor,
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[],
}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/import-sources/browse',
    body: <String, dynamic>{
      'library_id': libraryId,
      'entries': entries,
      'next_cursor': nextCursor,
    },
  );
}

Map<String, dynamic> _entry({
  required String ref,
  required String name,
  required String type,
  bool isVideo = false,
}) => <String, dynamic>{
  'source_ref': <String, dynamic>{'id': ref},
  'name': name,
  'entry_type': type,
  'size_bytes': type == 'file' ? 1024 : null,
  'modified_at': null,
  'is_video': isVideo,
};

Map<String, dynamic> _library() => <String, dynamic>{
  'id': 1,
  'name': '主媒体库',
  'provider_key': 'provider-a',
  'provider_config': <String, dynamic>{},
  'created_at': '2026-07-14T09:00:00Z',
  'updated_at': '2026-07-14T09:00:00Z',
};

Map<String, dynamic> _otherLibrary() => <String, dynamic>{
  'id': 2,
  'name': '其他媒体库',
  'provider_key': 'provider-b',
  'provider_config': <String, dynamic>{},
  'created_at': '2026-07-14T09:00:00Z',
  'updated_at': '2026-07-14T09:00:00Z',
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
    setState(() {
      _result =
          'result:${jsonEncode(request.source.sourceRef)}:${request.sourceDisposition.wireValue}';
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
