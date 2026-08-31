import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/joytag_hints.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/media_library_hints.dart';
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
  String url = 'https://torznab.example/torznab',
  int clientId = 1,
}) {
  return IndexerEntryDto(
    id: id,
    name: 'e$id',
    url: url,
    kind: 'pt',
    downloadClients:
        clientId > 0
            ? <IndexerBoundClientDto>[
              IndexerBoundClientDto(
                id: clientId,
                name: 'c',
                kind: DownloadClientKind.qbittorrent,
              ),
            ]
            : const <IndexerBoundClientDto>[],
  );
}

void main() {
  group('resolveDownloaderConnectivityHintKey', () {
    test('null error → unknown', () {
      expect(resolveDownloaderConnectivityHintKey(null), 'unknown');
    });

    // 后端 cloud115 分支的两个 type 是精确值，见 DownloadClientService._run_cloud115_probe。
    test('cloud115 cookies 失效 → 指向媒体库的 hint', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err(DownloaderErrorType.cloud115CookiesInvalid, '115 cookies 已失效'),
        ),
        DownloaderErrorType.cloud115CookiesInvalid,
      );
      expect(
        downloaderConnectivityHints[DownloaderErrorType.cloud115CookiesInvalid]!
            .fixTarget
            ?.configurationTabIndex,
        1,
        reason: '115 登录态挂在媒体库上，不在下载器页面改',
      );
    });

    test('cloud115 上游不可用 → 同样指向媒体库', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err(DownloaderErrorType.cloud115UpstreamError, '115 上游暂时不可用'),
        ),
        DownloaderErrorType.cloud115UpstreamError,
      );
      expect(
        downloaderConnectivityHints[DownloaderErrorType.cloud115UpstreamError]!
            .fixTarget
            ?.configurationTabIndex,
        1,
      );
    });

    // qB 只有一个 type，认证/网络只能靠 message 尽力细分。
    test('qB 请求失败 + message 提到登录 → auth 细分', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err(
            DownloaderErrorType.qbittorrentRequestError,
            'Login authorization failed.',
          ),
        ),
        'qbittorrent-auth-error',
      );
    });

    test('qB 请求失败 + message 提到 connection → network 细分', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err(
            DownloaderErrorType.qbittorrentRequestError,
            'HTTPConnectionPool(...): Connection refused',
          ),
        ),
        'qbittorrent-network-error',
      );
    });

    test('qB 请求失败 + message 无法判别 → 落回通用 qB 文案，不硬猜', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err(DownloaderErrorType.qbittorrentRequestError, 'something odd'),
        ),
        DownloaderErrorType.qbittorrentRequestError,
      );
    });

    test('后端发来未知 type → unknown（不再靠 message 猜出一个具体结论）', () {
      expect(
        resolveDownloaderConnectivityHintKey(
          _err('some_future_type', 'connection refused'),
        ),
        'unknown',
      );
    });
  });

  group('resolveDownloaderStorageHintKey', () {
    DownloadClientStorageTestResultDto storage({
      required String mappingStatus,
      bool sentinelVisible = true,
      bool hardlinkSupported = true,
      String? mappingErrorType,
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
          error: mappingErrorType == null ? null : _err(mappingErrorType),
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

    // 后端 mapping 失败分四种 type，各自的成因与修法完全不同，不能压成一条。
    test('本地根路径不可访问 → 对应到「路径没挂进容器」而不是「映射不通」', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(
            mappingStatus: 'failed',
            sentinelVisible: false,
            mappingErrorType: DownloaderErrorType.localRootNotAccessible,
          ),
        ),
        DownloaderErrorType.localRootNotAccessible,
      );
    });

    test('qB 看不到哨兵文件 → sentinel-not-visible', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(
            mappingStatus: 'failed',
            sentinelVisible: false,
            mappingErrorType: DownloaderErrorType.sentinelNotVisible,
          ),
        ),
        DownloaderErrorType.sentinelNotVisible,
      );
    });

    test('文件系统报错 → filesystem-error', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(
            mappingStatus: 'failed',
            sentinelVisible: false,
            mappingErrorType: DownloaderErrorType.filesystemError,
          ),
        ),
        DownloaderErrorType.filesystemError,
      );
    });

    test('mapping 失败但 type 未知 → unknown', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(
            mappingStatus: 'failed',
            sentinelVisible: false,
            mappingErrorType: 'some_future_type',
          ),
        ),
        'unknown',
      );
    });

    test('mapping ok 但 hardlink 不支持 → hardlink-not-supported', () {
      expect(
        resolveDownloaderStorageHintKey(
          storage(mappingStatus: 'ok', hardlinkSupported: false),
        ),
        DownloaderErrorType.hardlinkNotSupported,
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
      List<IndexerEntryDto> entries = const <IndexerEntryDto>[],
    }) {
      return IndexerSettingsDto(indexers: entries);
    }

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

    test('Torznab 请求失败及未知错误 → torznab-request-error', () {
      expect(
        resolveIndexerConnectionHintKey('torznab_request_error'),
        'torznab-request-error',
      );
      expect(
        resolveIndexerConnectionHintKey('unexpected_error'),
        'torznab-request-error',
      );
    });
  });

  group('resolveMetadataProviderHintKey', () {
    StatusMetadataProviderTestErrorDto error(
      String type, [
      String message = '',
    ]) {
      return StatusMetadataProviderTestErrorDto(type: type, message: message);
    }

    // 分派只看后端的 type。message 一律不参与判定，避免靠关键字匹配出错。
    test('按后端 type 分派，与 message 语言无关', () {
      expect(
        resolveMetadataProviderHintKey(
          error(MetadataProviderErrorType.notFound, 'movie not found: SSNI-888'),
        ),
        MetadataProviderErrorType.notFound,
      );
      expect(
        resolveMetadataProviderHintKey(
          error(
            MetadataProviderErrorType.requestError,
            'metadata request failed: GET https://x ()',
          ),
        ),
        MetadataProviderErrorType.requestError,
      );
      expect(
        resolveMetadataProviderHintKey(
          error(MetadataProviderErrorType.unexpected, 'boom'),
        ),
        MetadataProviderErrorType.unexpected,
      );
    });

    test('message 里的英文关键字不再影响结论', () {
      // 旧实现会把这条判成 "account-required"，而后端根本没有这个语义。
      expect(
        resolveMetadataProviderHintKey(
          error(MetadataProviderErrorType.requestError, 'Login required'),
        ),
        MetadataProviderErrorType.requestError,
      );
    });

    test('error 为 null 或 type 未知 → unexpected（文案就是「去看后端日志」）', () {
      expect(
        resolveMetadataProviderHintKey(null),
        MetadataProviderErrorType.unexpected,
      );
      expect(
        resolveMetadataProviderHintKey(error('some_future_type')),
        MetadataProviderErrorType.unexpected,
      );
    });
  });

  group('javdbHints', () {
    test('覆盖全部 hint key，控制器可以直接 ! 取值', () {
      const keys = <String>[
        MetadataProviderErrorType.notFound,
        MetadataProviderErrorType.requestError,
        MetadataProviderErrorType.unexpected,
        'probe-request-failed',
      ];
      for (final key in keys) {
        expect(javdbHints[key], isNotNull, reason: 'javdbHints 缺 $key');
      }
    });

    // JavDB 不再接收应用内代理配置，外部站点请求统一跟随容器环境变量分流。
    test('JavDB 的请求失败文案必须说明代理由环境变量分流', () {
      final hint = javdbHints[MetadataProviderErrorType.requestError]!;
      expect(hint.fixHint, contains('环境变量'));
      expect(hint.fixHint, contains('NO_PROXY'));
    });

    // 「高级设置 · JavDB API 域名」按 wiki config.md 是"不建议随便改"的字段，
    // 真正的修法在透明代理那一侧，所以 JavDB 一律不给跳转按钮。
    test('JavDB 一律不给 fixTarget，不引导用户去改域名', () {
      for (final entry in javdbHints.entries) {
        expect(
          entry.value.fixTarget,
          isNull,
          reason: 'javdbHints[${entry.key}] 不该给跳转，JavDB 没有用户该改的字段',
        );
      }
      for (final entry in javdbHints.entries) {
        expect(
          entry.value.fixHint,
          isNot(contains('换一个 JavDB 域名')),
          reason: 'javdbHints[${entry.key}] 不该教用户换域名，那是高级操作',
        );
      }
    });

    test('JavDB 连不上时把用户导向 wiki 的透明代理那一节', () {
      final hint = javdbHints[MetadataProviderErrorType.requestError]!;
      expect(hint.fixHint, contains('透明代理'));
      expect(hint.fixHint, contains('wiki'));
    });
  });

  // 这些文案直接显示在诊断页上，读者是自建 NAS 的普通用户，不是开发者。
  // 规矩定在 DiagnosticHint 的类注释里，这里做机械守卫，防止后续改动又滑回技术腔。
  group('文案风格守卫', () {
    final allHints = <String, DiagnosticHint>{
      for (final entry in downloaderConnectivityHints.entries)
        'downloaderConnectivity[${entry.key}]': entry.value,
      for (final entry in downloaderStorageHints.entries)
        'downloaderStorage[${entry.key}]': entry.value,
      for (final entry in indexerHints.entries)
        'indexer[${entry.key}]': entry.value,
      for (final entry in joyTagHints.entries)
        'joyTag[${entry.key}]': entry.value,
      for (final entry in javdbHints.entries)
        'javdb[${entry.key}]': entry.value,
      'mediaLibraryEmpty': mediaLibraryEmptyHint,
      'mediaLibraryProbeFailed': mediaLibraryProbeFailedHint,
    };

    /// 内部实现名词：用户没有这些词的语境，出现即为泄漏。
    const forbiddenJargon = <String>[
      '哨兵',
      'trust_env',
      'Torznab',
      'ld+json',
      'OSError',
      'collection',
      'entry',
      '5xx',
      '4xx',
      'tracker',
      '容器',
      '宿主机',
      'volume',
      '报文',
      '响应结构',
    ];

    /// 归因措辞：拿不准的原因不写，宁可只说"连不上"。
    const forbiddenHedging = <String>['多半', '可能是', '最常见的原因', '通常是', '之类'];

    test('不泄漏内部实现名词', () {
      allHints.forEach((label, hint) {
        for (final word in forbiddenJargon) {
          expect(
            '${hint.cause}${hint.fixHint}',
            isNot(contains(word)),
            reason: '$label 的文案里出现了内部名词「$word」',
          );
        }
      });
    });

    test('不写归因猜测', () {
      allHints.forEach((label, hint) {
        for (final word in forbiddenHedging) {
          expect(
            '${hint.cause}${hint.fixHint}',
            isNot(contains(word)),
            reason: '$label 的文案里出现了归因猜测「$word」',
          );
        }
      });
    });

    test('后端侧自称统一用「后端」，不混用「服务器」', () {
      allHints.forEach((label, hint) {
        expect(
          '${hint.cause}${hint.fixHint}',
          isNot(contains('服务器')),
          reason: '$label 用了「服务器」，应统一为「后端」',
        );
      });
    });

    test('cause / fixHint 都非空且是单句（不堆括号补丁）', () {
      allHints.forEach((label, hint) {
        expect(hint.cause, isNotEmpty, reason: '$label 缺 cause');
        expect(hint.fixHint, isNotEmpty, reason: '$label 缺 fixHint');
        // 一个「（…）」就是一次"没决定该砍什么"，全角括号一律不允许。
        expect(
          '${hint.cause}${hint.fixHint}',
          isNot(contains('（')),
          reason: '$label 用了括号补丁，把内容并进正文或删掉',
        );
      });
    });
  });
}
