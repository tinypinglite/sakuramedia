import 'package:sakuramedia/features/movies/data/missav_thumbnail_result_dto.dart';

class MissavThumbnailStreamUpdate {
  const MissavThumbnailStreamUpdate({
    required this.stage,
    required this.message,
    this.current,
    this.total,
    this.result,
    this.success,
    this.reason,
    this.detail,
  });

  final String stage;
  final String message;
  final int? current;
  final int? total;
  final MissavThumbnailResultDto? result;
  final bool? success;
  final String? reason;
  final String? detail;

  bool get isComplete => stage == 'completed';
}
