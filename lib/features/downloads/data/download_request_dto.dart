import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart'
    show MovieImageDto;

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
    required this.importStatusLabel,
    required this.createdAt,
    required this.updatedAt,
    this.movieTitle,
    this.movieCover,
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
  final String importStatusLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 后端 JOIN 出的中文/原始标题（优先中文）。仅当 movie_number 命中本地影片库时才有值；
  /// 未入库番号（predownload 场景）保持 null，前端 fallback 到 `name`。
  final String? movieTitle;

  /// 后端 JOIN 出的封面图。null 表示影片未入库或该影片无封面；前端用 MaskedImage 自带 placeholder。
  final MovieImageDto? movieCover;

  factory DownloadTaskDto.fromJson(Map<String, dynamic> json) {
    final coverRaw = json['movie_cover'];
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
      importStatusLabel: json['import_status_label'] as String? ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      movieTitle: json['movie_title'] as String?,
      movieCover: coverRaw is Map<String, dynamic>
          ? MovieImageDto.fromJson(coverRaw)
          : null,
    );
  }

  DownloadTaskDto copyWith({
    int? id,
    int? clientId,
    Object? movieNumber = _sentinel,
    String? name,
    String? infoHash,
    String? savePath,
    double? progress,
    String? downloadState,
    String? importStatus,
    String? importStatusLabel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    Object? movieTitle = _sentinel,
    Object? movieCover = _sentinel,
  }) {
    return DownloadTaskDto(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      movieNumber: identical(movieNumber, _sentinel)
          ? this.movieNumber
          : movieNumber as String?,
      name: name ?? this.name,
      infoHash: infoHash ?? this.infoHash,
      savePath: savePath ?? this.savePath,
      progress: progress ?? this.progress,
      downloadState: downloadState ?? this.downloadState,
      importStatus: importStatus ?? this.importStatus,
      importStatusLabel: importStatusLabel ?? this.importStatusLabel,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
      movieTitle: identical(movieTitle, _sentinel)
          ? this.movieTitle
          : movieTitle as String?,
      movieCover: identical(movieCover, _sentinel)
          ? this.movieCover
          : movieCover as MovieImageDto?,
    );
  }
}

const Object _sentinel = Object();

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
