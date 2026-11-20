import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 影片封面：按「图源 + 番号」择优渲染。
///
/// FC2- 番号用主封面 + [BoxFit.contain]（其封面多为横图，cover 会裁切）；其余
/// 优先用瘦封面（竖图，默认 cover 铺满），无瘦封面再退主封面 + contain；都缺失
/// 则渲染占位纯色块。桌面 / 移动摘要卡与电视卡片共用这套选择逻辑。
class MoviePosterCover extends StatelessWidget {
  const MoviePosterCover({
    super.key,
    required this.movie,
    this.memCacheWidth,
    this.placeholderKeyPrefix = 'movie-summary-card',
  });

  final MovieListItemDto movie;

  /// 解码宽度提示；不传时交给图片缓存按原始尺寸处理。
  final int? memCacheWidth;

  /// 缺图占位 key 的前缀；沿用各卡片的既有 key。
  final String placeholderKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final movieNumber = movie.movieNumber;
    final thinCoverUrl = movie.usesThinCover
        ? movie.thinCoverImage!.origin.trim()
        : null;
    final coverUrl = movie.hasWideCover
        ? movie.coverImage!.origin.trim()
        : null;

    if (movieNumber.startsWith('FC2-') && coverUrl != null) {
      return MaskedImage(
        url: coverUrl,
        fit: BoxFit.contain,
        memCacheWidth: memCacheWidth,
      );
    }

    if (thinCoverUrl != null) {
      return MaskedImage(url: thinCoverUrl, memCacheWidth: memCacheWidth);
    }

    if (coverUrl != null) {
      return MaskedImage(
        url: coverUrl,
        fit: BoxFit.contain,
        memCacheWidth: memCacheWidth,
      );
    }

    // 纯图片卡缺图态统一为 muted 纯色块：不带渐变 / 居中图标。
    return ColoredBox(
      key: Key('$placeholderKeyPrefix-placeholder-$movieNumber'),
      color: context.appColors.surfaceMuted,
    );
  }
}
