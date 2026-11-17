import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 配置页加载态占位数据：真实 DTO + [BoneMock] 文案，供 `AppSkeletonizer`
/// 渲染与真实内容同形的静态骨架。

List<MediaLibraryDto> mediaLibraryPlaceholders({int count = 4}) {
  return List<MediaLibraryDto>.generate(
    count,
    (index) => MediaLibraryDto(
      id: -1 - index,
      name: BoneMock.words(2),
      providerKey: 'provider',
      createdAt: null,
      updatedAt: null,
    ),
    growable: false,
  );
}

/// 占位 Provider：同时声明下载配置字段，让下载器页渲染「可新建」的真实形态。
List<MediaProviderDto> mediaProviderPlaceholders({int count = 1}) {
  return List<MediaProviderDto>.generate(
    count,
    (index) => const MediaProviderDto(
      providerKey: 'provider',
      displayName: 'Provider',
      libraryConfigFields: <ProviderConfigFieldDto>[],
      downloadConfigFields: <ProviderConfigFieldDto>[],
    ),
    growable: false,
  );
}

List<DownloadClientDto> downloadClientPlaceholders({int count = 3}) {
  return List<DownloadClientDto>.generate(
    count,
    (index) => DownloadClientDto(
      id: -1 - index,
      name: BoneMock.words(2),
      libraryId: -1 - index,
      createdAt: null,
      updatedAt: null,
    ),
    growable: false,
  );
}

List<IndexerEntryDto> indexerPlaceholders({int count = 3}) {
  return List<IndexerEntryDto>.generate(
    count,
    (index) => IndexerEntryDto(
      id: -1 - index,
      name: BoneMock.words(2),
      url: 'https://indexer.example.com',
      kind: 'torznab',
      downloadClients: const <IndexerBoundClientDto>[],
    ),
    growable: false,
  );
}
