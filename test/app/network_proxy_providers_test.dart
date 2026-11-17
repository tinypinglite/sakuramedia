import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/network_proxy_store.dart';
import 'package:sakuramedia/app/providers/network_proxy_providers.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = NetworkProxyConfig(host: '127.0.0.1', port: 7890);

  setUp(() => NetworkProxyRuntime.update(null));
  tearDown(() => NetworkProxyRuntime.update(null));

  test('defaults to no proxy', () {
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);

    expect(container.read(networkProxyControllerProvider), isNull);
    expect(NetworkProxyRuntime.config, isNull);
  });

  test('save and clear update state, store and runtime', () async {
    final store = InMemoryNetworkProxyStore();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [networkProxyStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(networkProxyControllerProvider.notifier).save(config);
    expect(container.read(networkProxyControllerProvider), config);
    expect(store.read(), config);
    expect(NetworkProxyRuntime.config, config);

    await container.read(networkProxyControllerProvider.notifier).clear();
    expect(container.read(networkProxyControllerProvider), isNull);
    expect(store.read(), isNull);
    expect(NetworkProxyRuntime.config, isNull);
  });

  test('build mirrors an injected store into the runtime', () {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        networkProxyStoreProvider.overrideWithValue(
          InMemoryNetworkProxyStore(config),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(networkProxyControllerProvider), config);
    expect(NetworkProxyRuntime.config, config);
  });
}
