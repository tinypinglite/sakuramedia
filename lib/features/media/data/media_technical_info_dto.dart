import 'package:sakuramedia/core/json/json_parse.dart';

/// 媒体列表展示所需的技术信息子集。
///
/// 后端 `video_info` 还包含音频、字幕等完整探测结果；列表只解析编码、
/// 码率和帧率，避免把详情域 DTO 带入列表数据层。
class MediaTechnicalInfoDto {
  const MediaTechnicalInfoDto({
    this.codecName,
    this.videoBitRate,
    this.containerBitRate,
    this.frameRate,
  });

  final String? codecName;
  final int? videoBitRate;
  final int? containerBitRate;
  final double? frameRate;

  factory MediaTechnicalInfoDto.fromVideoInfoJson(Map<String, dynamic> json) {
    final video = asMapOrNull(json['video']);
    final container = asMapOrNull(json['container']);
    return MediaTechnicalInfoDto(
      codecName: asStringOrNull(video?['codec_name'], trim: true),
      videoBitRate: asIntOrNull(video?['bit_rate']),
      containerBitRate: asIntOrNull(container?['bit_rate']),
      frameRate: asDoubleOrNull(video?['frame_rate']),
    );
  }
}
