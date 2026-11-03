import 'package:sakuramedia/core/json/json_parse.dart';

class MediaTransferLibraryDto {
  const MediaTransferLibraryDto({required this.id, required this.name});

  final int id;
  final String name;

  factory MediaTransferLibraryDto.fromJson(Map<String, dynamic> json) {
    return MediaTransferLibraryDto(
      id: asInt(json['id']),
      name: asStringOrNull(json['name'], trim: true) ?? '',
    );
  }
}

class MediaTransferCandidatesDto {
  const MediaTransferCandidatesDto({
    required this.sourceLibrary,
    required this.targets,
  });

  final MediaTransferLibraryDto sourceLibrary;
  final List<MediaTransferLibraryDto> targets;

  factory MediaTransferCandidatesDto.fromJson(Map<String, dynamic> json) {
    final source = asMapOrNull(json['source_library']);
    if (source == null) {
      throw const FormatException('media_transfer.source_library is required');
    }
    final targets = json['targets'];
    return MediaTransferCandidatesDto(
      sourceLibrary: MediaTransferLibraryDto.fromJson(source),
      targets: targets is List
          ? targets
                .whereType<Map>()
                .map(
                  (item) => MediaTransferLibraryDto.fromJson(
                    item.map(
                      (dynamic key, dynamic value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
          : const <MediaTransferLibraryDto>[],
    );
  }
}

class MediaTransferAcceptedResponseDto {
  const MediaTransferAcceptedResponseDto({
    required this.taskRunId,
    required this.taskKey,
    required this.state,
  });

  final int taskRunId;
  final String taskKey;
  final String state;

  factory MediaTransferAcceptedResponseDto.fromJson(Map<String, dynamic> json) {
    return MediaTransferAcceptedResponseDto(
      taskRunId: asInt(json['task_run_id']),
      taskKey: asStringOrNull(json['task_key'], trim: true) ?? '',
      state: asStringOrNull(json['state'], trim: true) ?? '',
    );
  }
}

enum MediaTransferFileStatus {
  pending,
  transferred,
  skipped,
  failed,
  cleanupIncomplete,
  unexecuted;

  static MediaTransferFileStatus fromWire(String? value) {
    return switch (value) {
      'transferred' => MediaTransferFileStatus.transferred,
      'skipped' => MediaTransferFileStatus.skipped,
      'failed' => MediaTransferFileStatus.failed,
      'cleanup_incomplete' => MediaTransferFileStatus.cleanupIncomplete,
      'unexecuted' => MediaTransferFileStatus.unexecuted,
      _ => MediaTransferFileStatus.pending,
    };
  }

  bool get isTransferred => this == MediaTransferFileStatus.transferred;
}

/// `GET /media-transfers/{task_run_id}/files` 的单文件迁移结果。
class MediaTransferFileDto {
  const MediaTransferFileDto({
    required this.mediaId,
    required this.fileName,
    required this.movieNumber,
    required this.sizeBytes,
    required this.status,
    required this.reasonCode,
    required this.targetCommitted,
  });

  final int mediaId;
  final String fileName;
  final String? movieNumber;
  final int sizeBytes;
  final MediaTransferFileStatus status;
  final String? reasonCode;
  final bool targetCommitted;

  factory MediaTransferFileDto.fromJson(Map<String, dynamic> json) {
    return MediaTransferFileDto(
      mediaId: asInt(json['media_id']),
      fileName: json['file_name'] as String? ?? '',
      movieNumber: asStringOrNull(json['movie_number'], trim: true),
      sizeBytes: asInt(json['size_bytes']),
      status: MediaTransferFileStatus.fromWire(json['status'] as String?),
      reasonCode: asStringOrNull(json['reason_code'], trim: true),
      targetCommitted: json['target_committed'] == true,
    );
  }
}
