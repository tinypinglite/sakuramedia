import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';

import '../../support/plugin_market_test_data.dart';
import '../../support/plugin_test_data.dart';

void main() {
  group('pluginMarketStatus', () {
    test('distinguishes not installed, installed and updatable', () {
      final item = pluginMarketItemDto(version: '1.1.0');

      expect(pluginMarketStatus(item, null), PluginMarketStatus.notInstalled);
      expect(
        pluginMarketStatus(item, pluginSummaryDto(version: '1.1.0')),
        PluginMarketStatus.installed,
      );
      expect(
        pluginMarketStatus(item, pluginSummaryDto(version: '1.0.0')),
        PluginMarketStatus.updateAvailable,
      );
    });

    test('installed version newer than the market is treated as installed', () {
      final item = pluginMarketItemDto(version: '1.0.0');

      expect(
        pluginMarketStatus(item, pluginSummaryDto(version: '1.2.0')),
        PluginMarketStatus.installed,
      );
    });

    test('unparsable versions fall back to installed', () {
      final item = pluginMarketItemDto(version: 'dev');

      expect(
        pluginMarketStatus(item, pluginSummaryDto(version: '1.0.0')),
        PluginMarketStatus.installed,
      );
    });
  });

  group('PluginMarket', () {
    late SessionStore store;
    late ApiClient apiClient;
    late _FakePluginsApi api;
    late ProviderContainer container;

    setUp(() {
      store = SessionStore.inMemory();
      apiClient = ApiClient(sessionStore: store);
      api = _FakePluginsApi(apiClient: apiClient);
      container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          pluginsApiProvider.overrideWithValue(api),
        ],
        retry: (_, __) => null,
      );
    });

    tearDown(() {
      container.dispose();
      apiClient.dispose();
      store.dispose();
    });

    PluginMarketCatalogDto catalogWith(List<PluginMarketItemDto> plugins) {
      return PluginMarketCatalogDto(schemaVersion: 1, plugins: plugins);
    }

    test('build loads the market catalog', () async {
      api.fetchMarketCatalogHandler = (_) async =>
          catalogWith(<PluginMarketItemDto>[pluginMarketItemDto()]);

      final state = await container.read(pluginMarketProvider.future);

      expect(state.catalog.plugins.single.pluginId, 'demo_plugin');
    });

    test('setKeyword filters visible plugins', () async {
      api.fetchMarketCatalogHandler = (_) async => catalogWith(<
        PluginMarketItemDto
      >[
        pluginMarketItemDto(
          pluginId: 'sakuramedia_115_provider',
          displayName: '115 网盘',
        ),
        pluginMarketItemDto(
          pluginId: 'sakuramedia_javbus_metadata',
          displayName: 'JavBus',
        ),
      ]);
      await container.read(pluginMarketProvider.future);

      container.read(pluginMarketProvider.notifier).setKeyword('javbus');

      final state = container.read(pluginMarketProvider).requireValue;
      expect(state.visiblePlugins.single.pluginId, 'sakuramedia_javbus_metadata');

      container.read(pluginMarketProvider.notifier).setKeyword('');
      expect(
        container.read(pluginMarketProvider).requireValue.visiblePlugins,
        hasLength(2),
      );
    });

    test('setKeyword matches every language variant', () async {
      api.fetchMarketCatalogHandler = (_) async => catalogWith(<
        PluginMarketItemDto
      >[
        pluginMarketItemDto(
          pluginId: 'sakuramedia_javbus_metadata',
          displayName: 'JavBus',
          displayNameI18n: <String, String>{
            'zh-CN': 'JavBus',
            'en': 'JavBus Metadata',
          },
          descriptionI18n: <String, String>{
            'zh-CN': '按番号补全元数据',
            'en': 'Fills in movie metadata by movie number',
          },
        ),
      ]);
      await container.read(pluginMarketProvider.future);

      container.read(pluginMarketProvider.notifier).setKeyword('metadata');

      final state = container.read(pluginMarketProvider).requireValue;
      expect(state.visiblePlugins.single.pluginId, 'sakuramedia_javbus_metadata');

      container.read(pluginMarketProvider.notifier).setKeyword('');
      expect(
        container.read(pluginMarketProvider).requireValue.visiblePlugins,
        hasLength(1),
      );
    });

    test('does not refetch the catalog when the interface language changes', () async {
      api.fetchMarketCatalogHandler = (_) async =>
          catalogWith(<PluginMarketItemDto>[pluginMarketItemDto()]);
      await container.read(pluginMarketProvider.future);
      expect(api.fetchMarketCatalogCalls, 1);

      await container
          .read(appLanguageControllerProvider.notifier)
          .setLanguage(AppLanguage.en);

      expect(api.fetchMarketCatalogCalls, 1);
    });

    test('install downloads, uploads with sha256 and reloads installed list', () async {
      api.fetchMarketCatalogHandler = (_) async =>
          catalogWith(<PluginMarketItemDto>[pluginMarketItemDto()]);
      var listCalls = 0;
      api.listHandler = () async {
        listCalls += 1;
        return listCalls == 1
            ? const <PluginSummaryDto>[]
            : <PluginSummaryDto>[
                pluginSummaryDto(id: 'demo_plugin', version: '1.1.0'),
              ];
      };
      await container.read(pluginsProvider.future);
      await container.read(pluginMarketProvider.future);

      Uint8List? uploadedBytes;
      String? uploadedFileName;
      String? uploadedSha256;
      api.downloadMarketReleaseHandler = (_) async =>
          Uint8List.fromList(<int>[80, 75, 3, 4]);
      api.installHandler = (bytes, fileName, sha256) async {
        uploadedBytes = bytes;
        uploadedFileName = fileName;
        uploadedSha256 = sha256;
      };

      await container
          .read(pluginMarketProvider.notifier)
          .install(pluginMarketItemDto());

      expect(uploadedBytes, <int>[80, 75, 3, 4]);
      expect(uploadedFileName, 'demo_plugin-1.1.0.zip');
      expect(
        uploadedSha256,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final marketState = container.read(pluginMarketProvider).requireValue;
      expect(marketState.busyPluginIds, isEmpty);
      expect(
        container
            .read(pluginsProvider)
            .requireValue
            .plugins
            .single
            .version,
        '1.1.0',
      );
    });

    test('upgrade downloads the release and reloads installed list', () async {
      api.fetchMarketCatalogHandler = (_) async =>
          catalogWith(<PluginMarketItemDto>[pluginMarketItemDto()]);
      var listCalls = 0;
      api.listHandler = () async {
        listCalls += 1;
        return <PluginSummaryDto>[
          pluginSummaryDto(
            id: 'demo_plugin',
            version: listCalls == 1 ? '1.0.0' : '1.1.0',
          ),
        ];
      };
      await container.read(pluginsProvider.future);
      await container.read(pluginMarketProvider.future);

      String? upgradedPluginId;
      PluginReleaseUpdate? upgradedRelease;
      api.downloadMarketReleaseHandler = (_) async =>
          Uint8List.fromList(<int>[80, 75, 3, 4]);
      api.upgradeHandler = (pluginId, update, bytes) async {
        upgradedPluginId = pluginId;
        upgradedRelease = update;
        return update.version;
      };

      await container
          .read(pluginMarketProvider.notifier)
          .upgrade(pluginMarketItemDto());

      expect(upgradedPluginId, 'demo_plugin');
      expect(upgradedRelease!.version, '1.1.0');
      expect(upgradedRelease!.assetFileName, 'demo_plugin-1.1.0.zip');
      expect(
        upgradedRelease!.sha256,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(
        container.read(pluginsProvider).requireValue.plugins.single.version,
        '1.1.0',
      );
    });

    test('failed install rethrows and clears busy state', () async {
      api.fetchMarketCatalogHandler = (_) async =>
          catalogWith(<PluginMarketItemDto>[pluginMarketItemDto()]);
      api.listHandler = () async => const <PluginSummaryDto>[];
      await container.read(pluginsProvider.future);
      await container.read(pluginMarketProvider.future);
      api.downloadMarketReleaseHandler = (_) async => throw StateError('offline');

      await expectLater(
        container.read(pluginMarketProvider.notifier).install(
          pluginMarketItemDto(),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        container.read(pluginMarketProvider).requireValue.busyPluginIds,
        isEmpty,
      );
    });
  });
}

class _FakePluginsApi extends PluginsApi {
  _FakePluginsApi({required super.apiClient});

  Future<PluginMarketCatalogDto> Function(String indexUrl)?
  fetchMarketCatalogHandler;

  /// 索引拉取次数：切语言不应该重新拉取市场目录。
  int fetchMarketCatalogCalls = 0;
  Future<Uint8List> Function(PluginMarketReleaseDto release)?
  downloadMarketReleaseHandler;
  Future<void> Function(Uint8List, String, String?)? installHandler;
  Future<String> Function(String, PluginReleaseUpdate, Uint8List)? upgradeHandler;
  Future<List<PluginSummaryDto>> Function()? listHandler;

  @override
  Future<PluginMarketCatalogDto> fetchMarketCatalog(String indexUrl) {
    fetchMarketCatalogCalls += 1;
    return fetchMarketCatalogHandler!(indexUrl);
  }

  @override
  Future<Uint8List> downloadMarketRelease(PluginMarketReleaseDto release) {
    return downloadMarketReleaseHandler!(release);
  }

  @override
  Future<void> install({
    required Uint8List fileBytes,
    required String fileName,
    String? sha256,
  }) {
    return installHandler!(fileBytes, fileName, sha256);
  }

  @override
  Future<String> upgrade({
    required String pluginId,
    required PluginReleaseUpdate update,
    required Uint8List fileBytes,
  }) {
    return upgradeHandler!(pluginId, update, fileBytes);
  }

  @override
  Future<List<PluginSummaryDto>> list() => listHandler!();
}
