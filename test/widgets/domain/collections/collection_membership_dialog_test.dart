import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_membership_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/preview_helpers.dart';
import '../../../support/test_api_bundle.dart';

class _FakeCollection {
  const _FakeCollection({required this.id, required this.name, this.count = 0});

  final int id;
  final String name;
  final int count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('loads membership and toggles add/remove optimistically', (
    tester,
  ) async {
    final addCalls = <int>[];
    final removeCalls = <int>[];
    final config = CollectionMembershipConfig<_FakeCollection>(
      keyPrefix: 'test-membership',
      title: '加入合集',
      searchHint: '搜索合集',
      createLabel: '新建合集',
      emptyMessage: '暂无合集',
      noMatchMessage: '没有匹配的合集',
      loadErrorFallback: '加载失败',
      addErrorFallback: '加入失败',
      removeErrorFallback: '移出失败',
      loadCollections: (ref) async => const <_FakeCollection>[
        _FakeCollection(id: 1, name: 'Alpha', count: 2),
        _FakeCollection(id: 2, name: 'Beta'),
      ],
      loadSelectedIds: (ref) async => <int>{1},
      add: (ref, collectionId) async => addCalls.add(collectionId),
      remove: (ref, collectionId) async => removeCalls.add(collectionId),
      createCollection: (context, ref) async => null,
      idOf: (collection) => collection.id,
      nameOf: (collection) => collection.name,
      countOf: (collection) => collection.count,
    );

    await pumpPreviewApp(
      tester,
      home: CollectionMembershipDialog<_FakeCollection>(config: config),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('test-membership-list')), findsOneWidget);
    expect(find.text('已选 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-membership-option-1')));
    await _pumpFrames(tester);
    expect(removeCalls, <int>[1]);
    expect(find.text('已选 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-membership-option-2')));
    await _pumpFrames(tester);
    expect(addCalls, <int>[2]);
    expect(find.text('已选 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
