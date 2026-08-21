import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/config_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_preference_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart'
    as media;
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';

void main() {
  late SessionStore store;
  late ApiClient apiClient;

  setUp(() {
    store = SessionStore.inMemory();
    apiClient = ApiClient(sessionStore: store);
  });

  tearDown(() {
    apiClient.dispose();
    store.dispose();
  });

  test('媒体库 provider 加载、失败恢复、CRUD 本地补丁和销毁后迟到回包', () async {
    final api = _FakeMediaLibrariesApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        mediaLibrariesApiProvider.overrideWithValue(api),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);

    api.getHandler = () async => throw StateError('offline');
    await expectLater(
      container.read(mediaLibrariesProvider.future),
      throwsA(isA<StateError>()),
    );
    api.getHandler = () async => [_library(1, 'Main')];
    await container.read(mediaLibrariesProvider.notifier).reload();
    expect(
      container.read(mediaLibrariesProvider).requireValue.single.name,
      'Main',
    );

    api.createHandler = (_) async => _library(2, 'Archive');
    await container
        .read(mediaLibrariesProvider.notifier)
        .create(
          const CreateMediaLibraryPayload(
            name: 'Archive',
            rootPath: '/archive',
          ),
        );
    expect(
      container.read(mediaLibrariesProvider).requireValue.map((it) => it.id),
      [2, 1],
    );

    await container.read(mediaLibrariesProvider.notifier).delete(1);
    expect(container.read(mediaLibrariesProvider).requireValue.single.id, 2);

    final late = Completer<MediaLibraryDto>();
    api.createHandler = (_) => late.future;
    final pending = container
        .read(mediaLibrariesProvider.notifier)
        .create(
          const CreateMediaLibraryPayload(name: 'Late', rootPath: '/late'),
        );
    container.dispose();
    late.complete(_library(3, 'Late'));
    expect((await pending).id, 3);
  });

  test('下载器 provider 会本地 upsert/remove，刷新失败保留当前列表', () async {
    final api = _FakeDownloadClientsApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        downloadClientsApiProvider.overrideWithValue(api),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);
    api.getHandler = () async => [_client(1, 'qB')];
    await container.read(downloadClientsProvider.future);

    api.createHandler = (_) async => _client(2, '115');
    await container
        .read(downloadClientsProvider.notifier)
        .create(
          const CreateDownloadClientPayload(
            name: '115',
            kind: DownloadClientKind.cloud115,
            mediaLibraryId: 1,
          ),
        );
    expect(
      container.read(downloadClientsProvider).requireValue.map((it) => it.id),
      [2, 1],
    );

    api.getHandler = () async => throw StateError('refresh failed');
    expect(
      await container.read(downloadClientsProvider.notifier).refresh(),
      contains('下载器加载失败'),
    );
    expect(container.read(downloadClientsProvider).requireValue.length, 2);

    await container.read(downloadClientsProvider.notifier).delete(2);
    expect(container.read(downloadClientsProvider).requireValue.single.id, 1);
  });

  test('索引器 provider 保存草稿，刷新失败保留草稿', () async {
    final api = _FakeIndexerSettingsApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        indexerSettingsApiProvider.overrideWithValue(api),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);
    api.getHandler = () async => _settings();
    await container.read(indexerSettingsProvider.future);

    final notifier = container.read(indexerSettingsProvider.notifier);
    notifier.updateDraft(indexers: <IndexerEntryDto>[_indexer(apiKey: 'draft')]);
    expect(
      container.read(indexerSettingsProvider).requireValue.isDirty,
      isTrue,
    );
    api.updateHandler = (payload) async {
      expect(payload.indexers.single.apiKey, 'draft');
      return _settings(indexers: <IndexerEntryDto>[_indexer(apiKey: 'saved')]);
    };
    await notifier.save();
    expect(
      container
          .read(indexerSettingsProvider)
          .requireValue
          .draft
          .indexers
          .single
          .apiKey,
      'saved',
    );

    api.getHandler = () async => throw StateError('refresh failed');
    expect(await notifier.refresh(), contains('索引器加载失败'));
    expect(
      container
          .read(indexerSettingsProvider)
          .requireValue
          .draft
          .indexers
          .single
          .apiKey,
      'saved',
    );
  });

  test('下载偏好仅 patch preferred_client_kinds 并返回 restart_required', () async {
    final api = _FakeConfigApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        configApiProvider.overrideWithValue(api),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);
    api.getHandler = () async => _config([DownloadClientKind.qbittorrent]);
    await container.read(downloadPreferenceProvider.future);

    final notifier = container.read(downloadPreferenceProvider.notifier);
    notifier.updateDraft(const [DownloadClientKind.cloud115]);
    api.patchHandler = (partial) async {
      expect(partial, {
        'downloads': {
          'preferred_client_kinds': ['cloud115'],
        },
      });
      return ConfigUpdateResultDto(
        values: _config(const [DownloadClientKind.cloud115]),
        restartRequired: const ['api'],
      );
    };

    final restart = await notifier.save();
    expect(restart.single, 'api');
    final state = container.read(downloadPreferenceProvider).requireValue;
    expect(state.isDirty, isFalse);
    expect(state.savedKinds, const [DownloadClientKind.cloud115]);
  });

  test('登出后配置型 keepAlive provider 失效，下次读拿的是新会话的数据', () async {
    await store.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-05T12:00:00Z'),
    );
    final api = _FakeIndexerSettingsApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        indexerSettingsApiProvider.overrideWithValue(api),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    var fetches = 0;
    api.getHandler = () async {
      fetches += 1;
      return _settings();
    };
    expect(
      (await container.read(indexerSettingsProvider.future)).draft.indexers,
      isEmpty,
    );

    // 索引器/下载器这类是账号级服务端配置，登出必须失效，
    // 否则换账号后仍会读到上一账号的设置。
    await store.clearSession();

    expect(
      (await container.read(indexerSettingsProvider.future)).draft.indexers,
      isEmpty,
    );
    expect(fetches, 2);
  });

  test('媒体库 CRUD 更新 media 域派生状态且只请求一次', () async {
    final api = _FakeMediaLibrariesApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        mediaLibrariesApiProvider.overrideWithValue(api),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    var fetches = 0;
    api.getHandler = () async {
      fetches += 1;
      return [_library(1, 'Main')];
    };
    await container.read(mediaLibrariesProvider.future);
    await container.read(media.mediaLibrariesProvider.future);
    expect(fetches, 1); // media 域从 configuration provider 派生
    expect(
      container
          .read(media.mediaLibrariesProvider)
          .requireValue
          .libraries
          .map((library) => library.id),
      [1],
    );

    api.createHandler = (_) async => _library(2, 'Archive');
    await container
        .read(mediaLibrariesProvider.notifier)
        .create(
          const CreateMediaLibraryPayload(
            name: 'Archive',
            rootPath: '/archive',
          ),
        );

    // media 域实时派生 configuration provider 的更新，不再重新请求。
    final refreshed = await container.read(media.mediaLibrariesProvider.future);
    expect(fetches, 1);
    expect(refreshed.libraries.map((library) => library.id), [2, 1]);
    expect(refreshed.storageDescriptors.keys, containsAll([1, 2]));
  });
}

class _FakeMediaLibrariesApi extends MediaLibrariesApi {
  _FakeMediaLibrariesApi({required super.apiClient});

  late Future<List<MediaLibraryDto>> Function() getHandler;
  Future<MediaLibraryDto> Function(CreateMediaLibraryPayload)? createHandler;

  @override
  Future<List<MediaLibraryDto>> getLibraries() => getHandler();

  @override
  Future<MediaLibraryDto> createLibrary(CreateMediaLibraryPayload payload) =>
      createHandler!(payload);

  @override
  Future<void> deleteLibrary(int libraryId) async {}
}

class _FakeDownloadClientsApi extends DownloadClientsApi {
  _FakeDownloadClientsApi({required super.apiClient});

  late Future<List<DownloadClientDto>> Function() getHandler;
  Future<DownloadClientDto> Function(CreateDownloadClientPayload)?
  createHandler;

  @override
  Future<List<DownloadClientDto>> getClients() => getHandler();

  @override
  Future<DownloadClientDto> createClient(CreateDownloadClientPayload payload) =>
      createHandler!(payload);

  @override
  Future<void> deleteClient(int clientId) async {}
}

class _FakeIndexerSettingsApi extends IndexerSettingsApi {
  _FakeIndexerSettingsApi({required super.apiClient});

  late Future<IndexerSettingsDto> Function() getHandler;
  Future<IndexerSettingsDto> Function(UpdateIndexerSettingsPayload)?
  updateHandler;

  @override
  Future<IndexerSettingsDto> getSettings() => getHandler();

  @override
  Future<IndexerSettingsDto> updateSettings(
    UpdateIndexerSettingsPayload payload,
  ) => updateHandler!(payload);
}

class _FakeConfigApi extends ConfigApi {
  _FakeConfigApi({required super.apiClient});

  late Future<ConfigResourceDto> Function() getHandler;
  Future<ConfigUpdateResultDto> Function(Map<String, dynamic>)? patchHandler;

  @override
  Future<ConfigResourceDto> get() => getHandler();

  @override
  Future<ConfigUpdateResultDto> patch(Map<String, dynamic> partial) =>
      patchHandler!(partial);
}

MediaLibraryDto _library(int id, String name) => MediaLibraryDto(
  id: id,
  name: name,
  rootPath: '/$name',
  createdAt: null,
  updatedAt: null,
);

DownloadClientDto _client(int id, String name) => DownloadClientDto(
  id: id,
  name: name,
  baseUrl: '',
  username: '',
  clientSavePath: '',
  localRootPath: '',
  mediaLibraryId: 1,
  hasPassword: false,
  createdAt: null,
  updatedAt: null,
);

IndexerEntryDto _indexer({String? apiKey}) => IndexerEntryDto(
  id: 1,
  name: 'mteam',
  url: 'https://example.com/torznab',
  kind: 'pt',
  apiKey: apiKey,
  downloadClients: const <IndexerBoundClientDto>[],
);

IndexerSettingsDto _settings({
  List<IndexerEntryDto> indexers = const <IndexerEntryDto>[],
}) => IndexerSettingsDto(indexers: indexers);

ConfigResourceDto _config(List<DownloadClientKind> kinds) => ConfigResourceDto(
  media: const AdvancedMediaConfigDto(
    othersNumberFeatures: [],
    innerSubTags: [],
    bluerayTags: [],
    uncensoredTags: [],
    uncensoredPrefix: [],
    allowedMinVideoFileSize: 0,
  ),
  metadata: const AdvancedMetadataConfigDto(javdbHost: ''),
  scheduler: const AdvancedSchedulerConfigDto(crons: {}),
  downloads: AdvancedDownloadsConfigDto(
    smallFileCleanupThresholdMb: 0,
    preferredClientKinds: kinds,
  ),
  logging: const AdvancedLoggingConfigDto(level: 'INFO'),
);
