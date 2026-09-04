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
