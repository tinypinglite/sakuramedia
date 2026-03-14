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
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class DownloadRequestResponseDto {
  const DownloadRequestResponseDto({required this.task, required this.created});

  final DownloadTaskDto task;
  final bool created;

  factory DownloadRequestResponseDto.fromJson(Map<String, dynamic> json) {
    return DownloadRequestResponseDto(
      task: DownloadTaskDto.fromJson(_toMap(json['task'])),
      created: json['created'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
