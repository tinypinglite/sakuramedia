import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_provider_catalog_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';

void main() {
  test('media provider catalog loads and can be reloaded', () async {
    final store = SessionStore.inMemory();
    final apiClient = ApiClient(sessionStore: store);
    final api = _FakeMediaProviderCatalogApi(apiClient: apiClient);
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        mediaProviderCatalogApiProvider.overrideWithValue(api),
      ],
      retry: (_, __) => null,
    );
    addTearDown(container.dispose);
    addTearDown(apiClient.dispose);
    addTearDown(store.dispose);

    api.providers = <MediaProviderDto>[_provider('first')];
    await expectLater(
      container.read(mediaProviderCatalogProvider.future),
      completion(hasLength(1)),
    );
    expect(
      container
          .read(mediaProviderCatalogProvider)
          .requireValue
          .single
          .providerKey,
      'first',
    );

    api.providers = <MediaProviderDto>[_provider('second')];
    await container.read(mediaProviderCatalogProvider.notifier).reload();
    expect(
      container
          .read(mediaProviderCatalogProvider)
          .requireValue
          .single
          .providerKey,
      'second',
    );
  });
}

class _FakeMediaProviderCatalogApi extends MediaProviderCatalogApi {
  _FakeMediaProviderCatalogApi({required super.apiClient});

  List<MediaProviderDto> providers = const <MediaProviderDto>[];

  @override
  Future<List<MediaProviderDto>> getProviders() async => providers;
}

MediaProviderDto _provider(String key) => MediaProviderDto(
  providerKey: key,
  displayName: key,
  libraryConfigFields: const <ProviderConfigFieldDto>[],
  downloadConfigFields: null,
);
