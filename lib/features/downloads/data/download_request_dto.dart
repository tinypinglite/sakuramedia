import 'package:sakuramedia/core/json/json_parse.dart';

class DownloadTaskDto {
  const DownloadTaskDto({
    required this.id,
    required this.clientId,
    required this.movieNumber,
    required this.name,
    required this.infoHash,
    required this.savePath,
    required this.progress,
    required this.downloadState,
    required this.importStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int clientId;
  final String? movieNumber;
  final String name;
  final String infoHash;
  final String savePath;
  final double progress;
  final String downloadState;
  final String importStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadTaskDto.fromJson(Map<String, dynamic> json) {
    return DownloadTaskDto(
      id: json['id'] as int? ?? 0,
      clientId: json['client_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String?,
      name: json['name'] as String? ?? '',
      infoHash: json['info_hash'] as String? ?? '',
      savePath: json['save_path'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadState: json['download_state'] as String? ?? '',
      importStatus: json['import_status'] as String? ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

class DownloadRequestResponseDto {
  const DownloadRequestResponseDto({required this.task, required this.created});

  final DownloadTaskDto task;
  final bool created;

  factory DownloadRequestResponseDto.fromJson(Map<String, dynamic> json) {
    return DownloadRequestResponseDto(
      task: DownloadTaskDto.fromJson(asMap(json['task'])),
      created: json['created'] as bool? ?? false,
    );
  }
}
