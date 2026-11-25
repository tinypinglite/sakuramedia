import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';
import 'package:sakuramedia/features/agent_connect/presentation/providers/agent_skills_provider.dart';
import 'package:sakuramedia/features/agent_connect/presentation/widgets/agent_connect_card.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/pump_with_providers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApiBundle bundle;

  setUp(() async {
    final sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('shows create guidance when no recoverable key exists', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'legacy',
          'key_hint': 'sk-legacy',
          'created_at': '2026-10-07T10:00:00Z',
          'last_used_at': null,
          'recoverable': false,
        },
      ],
    );

    await _pumpCard(tester, bundle);

    expect(find.byKey(const Key('agent-connect-create-key')), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/account/api-keys'), 0);
  });

  testWidgets('shows an upgrade hint when the backend has no reveal support', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'legacy',
          'key_hint': 'sk-legacy',
          'created_at': '2026-10-07T10:00:00Z',
          'last_used_at': null,
        },
      ],
    );

    await _pumpCard(tester, bundle);

    expect(find.text('当前后端不支持读取已有 API 密钥，请升级后端。'), findsOneWidget);
    expect(find.byKey(const Key('agent-connect-create-key')), findsNothing);
  });

  testWidgets('copies using the selected key without creating a new one', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 5,
          'name': 'agent',
          'key_hint': 'sk-AbCd1234',
          'created_at': '2026-10-07T10:00:00Z',
          'last_used_at': null,
          'recoverable': true,
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys/5/secret',
      body: <String, dynamic>{'key': 'sk-AbCd1234EfGh5678'},
    );

    await _pumpCard(tester, bundle);
    await tester.tap(find.byKey(const Key('agent-skill-sakuramedia-acquire')));
    await tester.tap(find.byKey(const Key('agent-api-key-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('agent-connect-copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(bundle.adapter.hitCount('GET', '/account/api-keys/5/secret'), 1);
    expect(bundle.adapter.hitCount('POST', '/account/api-keys'), 0);
  });
}

Future<void> _pumpCard(WidgetTester tester, TestApiBundle bundle) async {
  await pumpWithProviders(
    tester,
    home: const Scaffold(
      body: SingleChildScrollView(child: AgentConnectCard(isMobile: false)),
    ),
    bundle: bundle,
    theme: sakuraDesktopThemeData,
    physicalSize: const Size(1200, 900),
    overrides: [
      agentSkillsCatalogProvider.overrideWith(
        (ref) => const AgentSkillsCatalogDto(
          skills: <AgentSkillDto>[
            AgentSkillDto(
              name: 'sakuramedia-acquire',
              author: 'SakuraMedia',
              displayName: '补片',
              displayNameEn: 'Acquire',
              version: '0.1.0',
              description: '查片、下载并导入影片',
              descriptionEn: 'Find, download and import a movie',
              downloadUrl: 'https://example.com/acquire.zip',
            ),
          ],
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}
