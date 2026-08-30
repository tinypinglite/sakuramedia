import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        downloadsApiProvider.overrideWithValue(bundle.downloadsApi),
        downloadClientsApiProvider.overrideWithValue(bundle.downloadClientsApi),
      ],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  test('build loads a list snapshot with the current task fields', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);

    final state = await container.read(downloadTaskCenterProvider.future);

    expect(state.paged.items.single.task.id, 1);
    expect(state.paged.items.single.task.remoteId, 'remote-1');
    expect(state.paged.items.single.state, 'downloading');
    expect(state.clientOptions, const [
      DownloadClientOption(id: 2, name: 'qb-main'),
    ]);
    expect(state.clientNames, {2: 'qb-main'});
  });

  test('startPolling replaces the list with a fresh snapshot', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 1)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    _enqueueTaskPage(bundle, [taskJson(id: 2)], total: 1);
    await container.read(downloadTaskCenterProvider.notifier).startPolling();

    final state = container.read(downloadTaskCenterProvider).requireValue;
    expect(state.pollingState, DownloadTaskPollingState.polling);
    expect(state.paged.items.single.task.id, 2);
  });

  test('delete updates the current snapshot', () async {
    _enqueueTaskPage(bundle, [taskJson(id: 3)]);
    _enqueueClients(bundle);
    await container.read(downloadTaskCenterProvider.future);

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/download-tasks/3',
      statusCode: 204,
    );
    await container
        .read(downloadTaskCenterProvider.notifier)
        .deleteTask(3, deleteFiles: false);
    expect(
      container.read(downloadTaskCenterProvider).requireValue.paged.items,
      isEmpty,
    );
  });
}

Map<String, dynamic> taskJson({
  required int id,
  String state = 'downloading',
}) => <String, dynamic>{
  'id': id,
  'client_id': 2,
  'movie_number': 'ABC-00$id',
  'name': 'ABC-00$id',
  'remote_id': 'remote-$id',
  'state': state,
  'progress': 0.5,
  'import_status': 'pending',
  'import_status_label': '等待导入',
  'created_at': '2026-07-10T08:00:00Z',
  'updated_at': '2026-07-10T08:01:00Z',
};

void _enqueueTaskPage(
  TestApiBundle bundle,
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-tasks',
    body: <String, dynamic>{
      'items': items,
      'page': page,
      'page_size': 20,
      'total': total ?? items.length,
    },
  );
}

void _enqueueClients(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'name': 'qb-main',
        'library_id': 1,
        'provider_config': <String, dynamic>{'endpoint': 'http://qb:8080'},
      },
    ],
  );
}
