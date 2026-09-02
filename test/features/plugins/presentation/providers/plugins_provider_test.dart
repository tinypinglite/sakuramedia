import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';

import '../../support/plugin_test_data.dart';

void main() {
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

  test('build loads the plugin list', () async {
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(id: 'demo_plugin'),
    ];

    final state = await container.read(pluginsProvider.future);

    expect(state.plugins.single.pluginId, 'demo_plugin');
  });

  test('setEnabled replaces the item and clears busy state', () async {
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(id: 'demo_plugin', enabled: false),
    ];
    await container.read(pluginsProvider.future);
    api.setEnabledHandler = (_, __) async =>
        pluginSummaryDto(id: 'demo_plugin', enabled: true);

    await container
        .read(pluginsProvider.notifier)
        .setEnabled('demo_plugin', true);

    final state = container.read(pluginsProvider).requireValue;
    expect(state.plugins.single.enabled, isTrue);
    expect(state.busyPluginIds, isEmpty);
  });

  test('failed setEnabled rethrows and keeps the original list', () async {
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(id: 'demo_plugin', enabled: false),
    ];
    await container.read(pluginsProvider.future);
    api.setEnabledHandler = (_, __) async => throw StateError('offline');

    await expectLater(
      container.read(pluginsProvider.notifier).setEnabled('demo_plugin', true),
      throwsA(isA<StateError>()),
    );

    final state = container.read(pluginsProvider).requireValue;
    expect(state.plugins.single.enabled, isFalse);
    expect(state.busyPluginIds, isEmpty);
  });

  test('install reloads the list after upload', () async {
    api.listHandler = () async => <PluginSummaryDto>[];
    await container.read(pluginsProvider.future);

    api.installHandler = (_, __) async {};
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(id: 'demo_plugin'),
    ];

    final refreshed = await container
        .read(pluginsProvider.notifier)
        .install(
          fileBytes: Uint8List.fromList(<int>[80, 75]),
          fileName: 'demo.zip',
        );

    expect(refreshed, isTrue);
    expect(container.read(pluginsProvider).requireValue.plugins, hasLength(1));
    expect(container.read(pluginsProvider).requireValue.isInstalling, isFalse);
  });

  test('checks and installs an available plugin update', () async {
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(
        id: 'demo_plugin',
        releaseApiUrl:
            'https://api.github.com/repos/example/demo_plugin/releases/latest',
      ),
    ];
    await container.read(pluginsProvider.future);
    const update = PluginReleaseUpdate(
      version: '1.1.0',
      notes: '修复下载失败',
      assetUrl: 'https://github.com/example/demo/download.zip',
      assetFileName: 'demo_plugin-1.1.0.zip',
    );
    api.checkForUpdateHandler = (_) async => update;

    final allChecksSucceeded = await container
        .read(pluginsProvider.notifier)
        .checkUpdates();

    expect(allChecksSucceeded, isTrue);
    expect(
      container.read(pluginsProvider).requireValue.updates['demo_plugin'],
      update,
    );

    api.downloadUpdateHandler = (_) async => Uint8List.fromList(<int>[80, 75]);
    api.upgradeHandler = (_, __, ___) async => '1.1.0';
    await container.read(pluginsProvider.notifier).upgrade('demo_plugin');

    final state = container.read(pluginsProvider).requireValue;
    expect(state.plugins.single.version, '1.1.0');
    expect(state.updates, isEmpty);
    expect(state.busyPluginIds, isEmpty);
  });

  test(
    'keeps a known update when a later check for that plugin fails',
    () async {
      api.listHandler = () async => <PluginSummaryDto>[
        pluginSummaryDto(
          id: 'demo_plugin',
          releaseApiUrl:
              'https://api.github.com/repos/example/demo_plugin/releases/latest',
        ),
      ];
      await container.read(pluginsProvider.future);
      const update = PluginReleaseUpdate(
        version: '1.1.0',
        notes: '',
        assetUrl: 'https://github.com/example/demo/download.zip',
        assetFileName: 'demo_plugin-1.1.0.zip',
      );
      api.checkForUpdateHandler = (_) async => update;
      await container.read(pluginsProvider.notifier).checkUpdates();

      api.checkForUpdateHandler = (_) async => throw StateError('offline');
      final allChecksSucceeded = await container
          .read(pluginsProvider.notifier)
          .checkUpdates();

      expect(allChecksSucceeded, isFalse);
      expect(
        container.read(pluginsProvider).requireValue.updates['demo_plugin'],
        update,
      );
    },
  );

  test(
    'install keeps the old list and returns false when refresh fails',
    () async {
      api.listHandler = () async => <PluginSummaryDto>[];
      await container.read(pluginsProvider.future);
      api.installHandler = (_, __) async {};
      api.listHandler = () async => throw StateError('refresh failed');

      final refreshed = await container
          .read(pluginsProvider.notifier)
          .install(
            fileBytes: Uint8List.fromList(<int>[80, 75]),
            fileName: 'demo.zip',
          );

      expect(refreshed, isFalse);
      final state = container.read(pluginsProvider).requireValue;
      expect(state.plugins, isEmpty);
      expect(state.isInstalling, isFalse);
    },
  );

  test('remove deletes the item from local state', () async {
    api.listHandler = () async => <PluginSummaryDto>[
      pluginSummaryDto(id: 'demo_plugin'),
    ];
    await container.read(pluginsProvider.future);
    api.removeHandler = (_) async {};

    await container.read(pluginsProvider.notifier).remove('demo_plugin');

    expect(container.read(pluginsProvider).requireValue.plugins, isEmpty);
  });
}

class _FakePluginsApi extends PluginsApi {
  _FakePluginsApi({required super.apiClient});

  Future<List<PluginSummaryDto>> Function()? listHandler;
  Future<void> Function(Uint8List, String)? installHandler;
  Future<PluginReleaseUpdate?> Function(PluginSummaryDto)?
  checkForUpdateHandler;
  Future<Uint8List> Function(PluginReleaseUpdate)? downloadUpdateHandler;
  Future<String> Function(String, PluginReleaseUpdate, Uint8List)?
  upgradeHandler;
  Future<PluginSummaryDto> Function(String, bool)? setEnabledHandler;
  Future<void> Function(String)? removeHandler;

  @override
  Future<List<PluginSummaryDto>> list() => listHandler!();

  @override
  Future<void> install({
    required Uint8List fileBytes,
    required String fileName,
  }) {
    return installHandler!(fileBytes, fileName);
  }

  @override
  Future<PluginReleaseUpdate?> checkForUpdate(PluginSummaryDto plugin) {
    return checkForUpdateHandler!(plugin);
  }

  @override
  Future<Uint8List> downloadUpdate(PluginReleaseUpdate update) {
    return downloadUpdateHandler!(update);
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
  Future<PluginSummaryDto> setEnabled(
    String pluginId, {
    required bool enabled,
  }) {
    return setEnabledHandler!(pluginId, enabled);
  }

  @override
  Future<void> remove(String pluginId) {
    return removeHandler!(pluginId);
  }
}
