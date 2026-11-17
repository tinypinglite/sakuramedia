import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';

/// 推荐时刻 DTO → 时刻列表项 ViewModel(供预览浮层/播放跳转复用)。
/// 原挂在 `discovery_controller.dart` 文件尾,控制器迁 Riverpod 后独立成文件。
extension MomentRecommendationMomentItem on MomentRecommendationDto {
  MomentListItem toMomentListItem() {
    return MomentListItem(
      pointId: recommendationId,
      mediaId: mediaId,
      movieNumber: movie.movieNumber,
      thumbnailId: thumbnailId,
      offsetSeconds: offsetSeconds,
      image: image,
    );
  }
}
