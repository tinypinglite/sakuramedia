import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/network_proxy_store.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = NetworkProxyConfig(host: '127.0.0.1', port: 7890);

  test('in-memory store starts empty and persists', () async {
    final store = InMemoryNetworkProxyStore();

    expect(store.read(), isNull);
    await store.save(config);
    expect(store.read(), config);
    await store.save(null);
    expect(store.read(), isNull);
  });

  test('shared preferences store persists and clears', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesNetworkProxyStore(preferences);

    expect(store.read(), isNull);
    await store.save(config);
    expect(
      preferences.getString(SharedPreferencesNetworkProxyStore.proxyKey),
      '127.0.0.1:7890',
    );
    expect(store.read(), config);

    await store.save(null);
    expect(
      preferences.containsKey(SharedPreferencesNetworkProxyStore.proxyKey),
      isFalse,
    );
    expect(store.read(), isNull);
  });

  test('invalid stored value reads as unset', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesNetworkProxyStore.proxyKey: 'socks5://127.0.0.1:7890',
    });
    final store = SharedPreferencesNetworkProxyStore(
      await SharedPreferences.getInstance(),
    );

    expect(store.read(), isNull);
  });
}
