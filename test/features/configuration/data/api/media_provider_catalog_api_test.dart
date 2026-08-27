import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_provider_catalog_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  test(
    'GET /media-libraries/providers parses field metadata and null support',
    () async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries/providers',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'provider_key': 'local',
            'display_name': '本地存储与 qBittorrent',
            'library_config_fields': <Map<String, dynamic>>[
              <String, dynamic>{
                'key': 'media_root_path',
                'label': '媒体库路径',
                'input': 'path',
                'required': true,
                'multiline': false,
                'read_only': false,
                'description': '媒体文件最终存放目录。',
                'hint': '媒体文件最终存放目录',
              },
            ],
            'download_config_fields': null,
          },
          <String, dynamic>{
            'provider_key': 'empty-download',
            'display_name': '无需额外配置',
            'library_config_fields': <dynamic>[],
            'download_config_fields': <dynamic>[],
          },
        ],
      );

      final providers = await MediaProviderCatalogApi(
        apiClient: bundle.apiClient,
      ).getProviders();

      expect(providers, hasLength(2));
      expect(providers.first.providerKey, 'local');
      expect(
        providers.first.libraryConfigFields.single.input,
        ProviderConfigFieldInput.path,
      );
      expect(
        providers.first.libraryConfigFields.single.description,
        '媒体文件最终存放目录。',
      );
      expect(providers.first.downloadConfigFields, isNull);
      expect(providers.last.downloadConfigFields, isEmpty);
      expect(bundle.adapter.requests.single.path, '/media-libraries/providers');
    },
  );

  test('provider catalog DTO rejects malformed field metadata', () {
    expect(
      () => MediaProviderDto.fromJson(<String, dynamic>{
        'provider_key': 'local',
        'display_name': 'Local',
        'library_config_fields': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'root',
            'label': 'Root',
            'input': 'select',
            'required': true,
            'multiline': false,
            'read_only': false,
          },
        ],
        'download_config_fields': null,
      }),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => MediaProviderDto.fromJson(<String, dynamic>{
        'provider_key': 'local',
        'display_name': 'Local',
        'library_config_fields': const <dynamic>[],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
