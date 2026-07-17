import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

class MediaStorageDescriptor {
  const MediaStorageDescriptor({
    required this.libraryId,
    required this.libraryName,
    required this.backend,
  });

  const MediaStorageDescriptor.unknown({this.libraryId})
      : libraryName = null,
        backend = null;

  final int? libraryId;
  final String? libraryName;
  final MediaLibraryBackend? backend;

  bool get isLocal => backend == MediaLibraryBackend.local;
  bool get isCloud115 => backend == MediaLibraryBackend.cloud115;

  String get sourceLabel => switch (backend) {
        MediaLibraryBackend.local => '本地存储',
        MediaLibraryBackend.cloud115 => '115 网盘',
        null => '存储来源未知',
      };

  String? get normalizedLibraryName {
    final value = libraryName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory MediaStorageDescriptor.fromLibrary(MediaLibraryDto library) {
    return MediaStorageDescriptor(
      libraryId: library.id,
      libraryName: library.name,
      backend: library.backend,
    );
  }
}

Map<int, MediaStorageDescriptor> buildMediaStorageDescriptors(
  Iterable<MediaLibraryDto> libraries,
) {
  return <int, MediaStorageDescriptor>{
    for (final library in libraries)
      library.id: MediaStorageDescriptor.fromLibrary(library),
  };
}

MediaStorageDescriptor resolveMediaStorageDescriptor(
  int? libraryId,
  Map<int, MediaStorageDescriptor> descriptors,
) {
  if (libraryId == null) {
    return const MediaStorageDescriptor.unknown();
  }
  return descriptors[libraryId] ??
      MediaStorageDescriptor.unknown(libraryId: libraryId);
}

extension MediaStorageLocationFormat on MediaStorageDescriptor {
  /// 把 media 或失效媒体的原始 path 翻译成用户友好的显示文本。
  ///
  /// - 115 网盘：去掉 `cloud115:` 前缀显示文件名；无文件名时显示"115 网盘媒体"；
  /// - 本地：空 path 走 [sourceLabel]，否则原样返回 raw；
  /// - 未知 backend：与本地同样处理。
  ///
  /// 之前分散在 `MediaListPane._MediaRow._storageLocationText` 与
  /// `_InvalidMediaCard._storageLocationText` 两处，逻辑一致，收敛到此。
  String formatLocationText(String rawPath) {
    final raw = rawPath.trim();
    if (isCloud115 && raw.startsWith('cloud115:')) {
      final fileName = raw.substring('cloud115:'.length).trim();
      return fileName.isEmpty ? '115 网盘媒体' : fileName;
    }
    return raw.isEmpty ? sourceLabel : raw;
  }

  /// 把媒体库名翻译成用户友好的显示文本；无 name 时显示 "媒体库 {id}" 或"媒体库已删除"。
  String formatLibraryText({int? libraryId}) {
    final name = normalizedLibraryName;
    if (name != null) {
      return isCloud115 ? '$name（115）' : name;
    }
    if (libraryId == null) {
      return '媒体库已删除';
    }
    return '媒体库 $libraryId';
  }
}
