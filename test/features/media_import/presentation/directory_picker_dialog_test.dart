import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens a directory before selecting it as the import source', (
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
    _enqueueBrowse(
      bundle,
      libraryId: 1,
      parentRef: <String, dynamic>{'id': 'folder-1'},
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);

    await tester.tap(find.byKey(const Key('media-import-entry-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('media-import-picker-select-current-directory-button'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('media-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    final state = tester.state<_PickerHarnessState>(
      find.byType(_PickerHarness),
    );
    expect(state._result, 'result:{"id":"folder-1"}:keep');
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
    await tester.tap(find.byKey(const Key('media-import-entry-0')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('media-import-picker-load-more-button')),
    );
    await tester.pumpAndSettle();
    final browseRequest = bundle.adapter.requests.last;
    expect(browseRequest.body, <String, dynamic>{
      'library_id': 1,
      'parent_ref': <String, dynamic>{'id': 'folder-1'},
      'cursor': 'next',
      'limit': 50,
    });
  });

  testWidgets('offers in-place import when the library supports it', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueLibraries(bundle, <Map<String, dynamic>>[
      _library(supportsInPlace: true),
    ]);
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
    );

    await _pumpHarness(tester, bundle);
    await _openPicker(tester);
    await tester.tap(
      find.byKey(const Key('media-import-picker-source-disposition-select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('原地导入（不复制文件）'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('media-import-entry-0')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('media-import-picker-select-current-directory-button'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('media-import-picker-submit-button')),
    );
    await tester.pumpAndSettle();

    final state = tester.state<_PickerHarnessState>(
      find.byType(_PickerHarness),
    );
    expect(state._result, 'result:{"id":"folder-1"}:in_place');
  });

  testWidgets('falls back to keep when the library cannot import in place', (
    tester,
  ) async {
    final bundle = await _buildBundle();
    addTearDown(bundle.dispose);
    _enqueueBrowse(bundle, libraryId: 1);
    final received = <SourceDisposition>[];

    await _pumpWidget(
      tester,
      bundle,
      MediaImportSourcePicker(
        selectedLibrary: MediaLibraryDto.fromJson(_library()),
        sourceDisposition: SourceDisposition.inPlace,
        onSourceChanged: (_) {},
        onSourceDispositionChanged: received.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(received, <SourceDisposition>[SourceDisposition.keep]);
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

Future<void> _pumpHarness(WidgetTester tester, TestApiBundle bundle) {
  return _pumpWidget(tester, bundle, const _PickerHarness());
}

Future<void> _pumpWidget(
  WidgetTester tester,
  TestApiBundle bundle,
  Widget child,
) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        theme: sakuraThemeData,
        home: Scaffold(body: child),
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

Map<String, dynamic> _library({bool supportsInPlace = false}) =>
    <String, dynamic>{
      'id': 1,
      'name': '主媒体库',
      'provider_key': 'provider-a',
      'provider_config': <String, dynamic>{},
      'supports_in_place_import': supportsInPlace,
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
