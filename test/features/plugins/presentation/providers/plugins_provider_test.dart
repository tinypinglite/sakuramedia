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
