import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_tag_assignment_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-10-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() => bundle.dispose());

  Widget wrap({bool mobile = false}) {
    return ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const Key('open-assignment-editor'),
                  onPressed: () => showMediaTagAssignmentEditor(
                    context,
                    mediaId: 42,
                    mobile: mobile,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saves an exact manual tag selection', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[
        _tagJson(1, '4K', enabled: true),
        _tagJson(2, 'Subtitles', enabled: false),
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/42/tags',
      body: _assignmentJson(
        tags: [
          {'id': 1, 'name': '4K'},
        ],
        manual: false,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-assignment-editor')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-tag-assignment-dialog')),
      findsOneWidget,
    );
    expect(find.text('自动匹配'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/media/42/tags',
      body: _assignmentJson(
        tags: [
          {'id': 1, 'name': '4K'},
          {'id': 2, 'name': 'Subtitles'},
        ],
        manual: true,
      ),
    );
    await tester.tap(find.byKey(const Key('media-tag-assignment-tag-2')));
    await tester.tap(find.byKey(const Key('media-tag-assignment-save')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.method == 'PUT' && request.path == '/media/42/tags',
    );
    expect(request.body, {
      'tag_ids': [1, 2],
    });
    expect(find.byKey(const Key('media-tag-assignment-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores automatic tags after manual takeover', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[_tagJson(1, '4K', enabled: true)],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/42/tags',
      body: _assignmentJson(
        tags: [
          {'id': 1, 'name': '4K'},
        ],
        manual: true,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-assignment-editor')));
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media/42/tags/reset',
      body: _assignmentJson(tags: const [], manual: false),
    );
    await tester.tap(find.byKey(const Key('media-tag-assignment-reset-auto')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('media-tag-assignment-reset-confirm')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/media/42/tags/reset'), 1);
    expect(find.byKey(const Key('media-tag-assignment-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens as a mobile drawer and saves an empty selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[_tagJson(1, '4K', enabled: true)],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/42/tags',
      body: _assignmentJson(
        tags: [
          {'id': 1, 'name': '4K'},
        ],
        manual: false,
      ),
    );
    await tester.pumpWidget(wrap(mobile: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-assignment-editor')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-tag-assignment-drawer')),
      findsOneWidget,
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/media/42/tags',
      body: _assignmentJson(tags: const [], manual: true),
    );
    await tester.tap(find.byKey(const Key('media-tag-assignment-tag-1')));
    await tester.tap(find.byKey(const Key('media-tag-assignment-save')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.method == 'PUT' && request.path == '/media/42/tags',
    );
    expect(request.body, {'tag_ids': <int>[]});
    expect(find.byKey(const Key('media-tag-assignment-drawer')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _tagJson(int id, String name, {required bool enabled}) => {
  'id': id,
  'name': name,
  'include_terms': [name.toLowerCase()],
  'exclude_terms': <dynamic>[],
  'enabled': enabled,
  'media_count': 0,
  'created_at': '2026-10-30T01:02:03Z',
  'updated_at': '2026-10-30T01:02:03Z',
};

Map<String, dynamic> _assignmentJson({
  required List<Map<String, dynamic>> tags,
  required bool manual,
}) => {'media_id': 42, 'tags': tags, 'is_media_tags_manually_managed': manual};
