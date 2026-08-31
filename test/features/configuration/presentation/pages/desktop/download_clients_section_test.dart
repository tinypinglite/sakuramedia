import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_clients_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'editing a client with an unavailable provider preserves its library and config',
    (tester) async {
      Future<UpdateDownloadClientPayload?>? result;
      const client = DownloadClientDto(
        id: 1,
        name: 'Downloader',
        libraryId: 7,
        providerConfig: <String, dynamic>{'endpoint': 'http://old'},
        createdAt: null,
        updatedAt: null,
      );
      const library = MediaLibraryDto(
        id: 7,
        name: 'Main Library',
        providerKey: 'missing-provider',
        providerConfig: <String, dynamic>{'root': '/media'},
        createdAt: null,
        updatedAt: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  result = showDialog<UpdateDownloadClientPayload>(
                    context: context,
                    builder: (_) => const DownloadClientDialog(
                      libraries: <MediaLibraryDto>[library],
                      providers: const [],
                      title: '编辑下载器',
                      initialClient: client,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Main Library'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('download-client-name-field')),
        'Renamed downloader',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final payload = await result;
      expect(payload?.toJson(), <String, dynamic>{
        'name': 'Renamed downloader',
        'library_id': 7,
      });
    },
  );

  testWidgets(
    'keeps existing clients visible when the provider catalog request fails',
    (tester) async {
      final sessionStore = SessionStore.inMemory();
      addTearDown(sessionStore.dispose);
      await sessionStore.saveBaseUrl('https://api.example.com');
      await sessionStore.saveTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-clients',
        body: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'Downloader',
            'library_id': 7,
            'provider_config': <String, dynamic>{'endpoint': 'http://old'},
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries',
        body: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'name': 'Main Library',
            'provider_key': 'missing-provider',
            'provider_config': <String, dynamic>{'root': '/media'},
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries/providers',
        statusCode: 500,
        body: const <String, dynamic>{'message': 'catalog unavailable'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: OKToast(
            child: MaterialApp(
              theme: sakuraThemeData,
              home: const Scaffold(body: DownloadClientsSection(active: true)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('download-client-card-1')), findsOneWidget);
      expect(find.textContaining('Provider 目录暂不可用'), findsOneWidget);
      final createButton = tester.widget<AppSettingCell>(
        find.byKey(const Key('configuration-download-client-create-button')),
      );
      expect(createButton.onTap, isNull);
    },
  );
}
