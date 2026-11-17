import 'package:sakuramedia/core/format/image_file_extension.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';

String resolveMomentImageUrl(MomentListItem item) {
  final image = item.image;
  if (image == null) {
    return '';
  }
  return image.origin;
}

String buildMomentImageFileName(MomentListItem item, String imageUrl) {
  final extension = guessImageFileExtension(imageUrl, fallback: 'webp');
  final movieNumber = item.movieNumber;
  if (movieNumber != null && movieNumber.isNotEmpty) {
    return 'moment_${movieNumber}_${item.pointId}.$extension';
  }
  return 'moment_video_${item.videoItemId ?? 0}_${item.pointId}.$extension';
}
