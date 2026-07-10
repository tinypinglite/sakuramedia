import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/downloader_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/indexer_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/metadata_provider_hints.dart';

DownloadClientDiagnosticErrorDto _err(String type, [String message = '']) {
  return DownloadClientDiagnosticErrorDto(type: type, message: message);
}

DownloadClientDto _client(int id) {
  return DownloadClientDto(
    id: id,
    name: 'client-$id',
    baseUrl: '',
    username: '',
    clientSavePath: '',
    localRootPath: '',
    mediaLibraryId: 1,
    hasPassword: false,
    createdAt: null,
    updatedAt: null,
  );
}

IndexerEntryDto _entry({
  int id = 1,
  String url = 'https://jackett.example/torznab',
  int clientId = 1,
}) {
  return IndexerEntryDto(
    id: id,
    name: 'e$id',
    url: url,
    kind: 'jackett',
    downloadClientId: clientId,
    downloadClientName: 'c',
  );
}

void main() {
  group('resolveDownloaderConnectivityHintKey', () {
    test('null error → unknown', () {
      expect(resolveDownloaderConnectivityHintKey(null), 'unknown');
    });
    test('type 含 auth → auth-error', () {
      expect(
        resolveDownloaderConnectivityHintKey(_err('auth_failed')),
        'auth-error',
      );
    });
    test('type 含 timeout → network-error', () {
      expect(
        resolveDownloaderConnectivityHintKey(_err('connect_timeout')),
        'network-error',
      );
    });
    test('message 关键字兜底 → 命中 network', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err('runtime', 'connection refused'),
        ),
        'network-error',
      );
    });
    test('无匹配 → unknown', () {
      expect(
        resolveDownloaderConnectivityHintKey(_err('random_thing')),
        'unknown',
      );
    });
  });

  group('resolveDownloaderStorageHintKey', () {
    DownloadClientStorageTestResultDto storage({
      required String mappingStatus,
      bool sentinelVisible = true,
      bool hardlinkSupported = true,
    }) {
      return DownloadClientStorageTestResultDto(
        healthy: true,
        checkedAt: null,
        clientId: 1,
        clientName: 'c',
        elapsedMs: 0,
        warnings: const <String>[],
        directoryMapping: DownloadClientStorageDirectoryMappingResultDto(
          status: mappingStatus,
          clientSavePath: '',
          localRootPath: '',
          probeRemoteDir: '',
          probeLocalDir: '',
          sentinelVisibleToQb: sentinelVisible,
          error: null,
        ),
        hardlink: DownloadClientStorageHardlinkResultDto(
          status: 'ok',
          supported: hardlinkSupported,
          sourcePath: '',
          targetPath: '',
          error: null,
        ),
      );
    }

    test('mapping 不 ok → storage-mapping-error', () {
      expect(
        resolveDownloaderStorageHintKey(storage(mappingStatus: 'error')),
        'storage-mapping-error',
      );
    });
    test('mapping ok 但 hardlink 不支持 → hardlink-unsupported', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(mappingStatus: 'ok', hardlinkSupported: false),
        ),
        'hardlink-unsupported',
      );
    });
    test('全通过 → unknown（healthy 分支不会触到这里）', () {
      expect(
        resolveDownloaderStorageHintKey(storage(mappingStatus: 'ok')),
        'unknown',
      );
    });
  });

  group('resolveIndexerConfigHintKey', () {
    IndexerSettingsDto settings({
      String type = 'jackett',
      String apiKey = 'k',
      List<IndexerEntryDto> entries = const <IndexerEntryDto>[],
    }) {
      return IndexerSettingsDto(type: type, apiKey: apiKey, indexers: entries);
    }

    test('type 空 → type-missing', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(type: ''),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'type-missing',
      );
    });

    test('apiKey 空 → api-key-missing', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(apiKey: '  '),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'api-key-missing',
      );
    });

    test('entries 空 → entries-empty', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'entries-empty',
      );
    });

    test('entry URL 非法 → entry-url-invalid', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(
            entries: <IndexerEntryDto>[_entry(url: 'ftp://x')],
          ),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'entry-url-invalid',
      );
    });

    test('entry.downloadClientId 为 0 → entry-client-missing', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(entries: <IndexerEntryDto>[_entry(clientId: 0)]),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'entry-client-missing',
      );
    });

    test('entry.downloadClientId 指向已删下载器 → entry-client-stale', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(entries: <IndexerEntryDto>[_entry(clientId: 42)]),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        'entry-client-stale',
      );
    });

    test('全通过 → null（表示可继续执行在线连通性检测）', () {
      expect(
        resolveIndexerConfigHintKey(
          settings: settings(entries: <IndexerEntryDto>[_entry(clientId: 1)]),
          existingClients: <DownloadClientDto>[_client(1)],
        ),
        isNull,
      );
    });
  });

  group('resolveIndexerConnectionHintKey', () {
    test('未配置索引器 → no-indexers-configured', () {
      expect(
        resolveIndexerConnectionHintKey('no_indexers_configured'),
        'no-indexers-configured',
      );
    });

    test('Jackett 请求失败及未知错误 → jackett-request-error', () {
      expect(
        resolveIndexerConnectionHintKey('jackett_request_error'),
        'jackett-request-error',
      );
      expect(
        resolveIndexerConnectionHintKey('unexpected_error'),
        'jackett-request-error',
      );
    });
  });

  group('resolveMetadataProviderHintKey', () {
    test('message 含 login → account-required', () {
      expect(
        resolveMetadataProviderHintKey(
          provider: 'javdb',
          error: StatusMetadataProviderTestErrorDto(message: 'Login required'),
        ),
        'account-required',
      );
    });

    test('message 含 timeout → proxy-required', () {
      expect(
        resolveMetadataProviderHintKey(
          provider: 'javdb',
          error: StatusMetadataProviderTestErrorDto(message: 'timeout'),
        ),
        'proxy-required',
      );
    });

    test('DMM 未匹配关键字 → dmm-blocked（用于 IP 拒绝兜底）', () {
      expect(
        resolveMetadataProviderHintKey(
          provider: 'dmm',
          error: StatusMetadataProviderTestErrorDto(message: 'some junk'),
        ),
        'dmm-blocked',
      );
    });

    test('JavDB 未匹配关键字 → unknown', () {
      expect(
        resolveMetadataProviderHintKey(
          provider: 'javdb',
          error: StatusMetadataProviderTestErrorDto(message: 'some junk'),
        ),
        'unknown',
      );
    });
  });
}
