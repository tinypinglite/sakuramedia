import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart'
    show MovieImageDto;

class DownloadTaskDto {
  const DownloadTaskDto({
    required this.id,
    required this.clientId,
    required this.movieNumber,
    required this.name,
    required this.remoteId,
    required this.state,
    required this.progress,
    required this.importStatus,
    required this.importStatusLabel,
    required this.createdAt,
    required this.updatedAt,
    this.movieTitle,
    this.movieCover,
    this.movieThinCover,
  });

  final int id;
  final int clientId;
  final String? movieNumber;
  final String name;
  final String remoteId;
  final String state;
  final double progress;
  final String importStatus;
  final String importStatusLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 后端 JOIN 出的中文标题。仅当 movie_number 命中本地影片库时才有值。
  final String? movieTitle;

  /// 后端 JOIN 出的封面图。null 表示影片未入库或该影片无封面；前端用 MaskedImage 自带 placeholder。
  final MovieImageDto? movieCover;

  /// 后端 JOIN 出的竖版封面。旧后端不返回该字段时为 null，移动端回退使用 [movieCover]。
  final MovieImageDto? movieThinCover;

  factory DownloadTaskDto.fromJson(Map<String, dynamic> json) {
    final coverRaw = json['movie_cover'];
    final thinCoverRaw = json['movie_thin_cover'];
    return DownloadTaskDto(
      id: json['id'] as int? ?? 0,
      clientId: json['client_id'] as int? ?? 0,
      movieNumber: json['movie_number'] as String?,
      name: json['name'] as String? ?? '',
      remoteId: json['remote_id'] as String? ?? '',
      state: json['state'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      importStatus: json['import_status'] as String? ?? '',
      importStatusLabel: json['import_status_label'] as String? ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      movieTitle: json['movie_title'] as String?,
      movieCover: coverRaw is Map<String, dynamic>
          ? MovieImageDto.fromJson(coverRaw)
          : null,
      movieThinCover: thinCoverRaw is Map<String, dynamic>
          ? MovieImageDto.fromJson(thinCoverRaw)
          : null,
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
