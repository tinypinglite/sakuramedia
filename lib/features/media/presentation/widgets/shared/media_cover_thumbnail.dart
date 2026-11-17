import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// media feature 内部的通用封面缩略图：fixed size + placeholder/MaskedImage。
///
/// 之前分散在 `media_list_pane._MediaCover` 与 `desktop_media_maintenance_page._InvalidMediaCover`
/// 两份几乎照抄的实现里，合并到本文件；双端可用（尺寸由调用方传，跟随 layout token）。
///
/// **不自带圆角**：作为左封面卡的贴边封面时，四角应是直角，由外层卡片的
/// `Clip.antiAlias` 统一裁出外角圆角——否则会在卡里出现一张「四角都圆」的内嵌小卡。
///
/// - [url]：远程封面地址，空/null → 走 placeholder；
/// - [width]/[height]：由页面按 `context.appComponentTokens.mobileFollowMovieXxx` 传入；
/// - [fit]：多为 `usesThinCover ? cover : contain`；
/// - [placeholderKey]/[imageKey]：给测试锚点，两个 key 二选一命中（有 url 用 imageKey，否则 placeholderKey）；
/// - [placeholderBackground]：占位背景色，默认 [AppColors.surfaceCard]；维护页历史用 `surfaceMuted`——可覆盖。
class MediaCoverThumbnail extends StatelessWidget {
  const MediaCoverThumbnail({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.placeholderKey,
    this.imageKey,
    this.placeholderBackground,
  });

  final String? url;
  final double width;
  final double height;
  final BoxFit fit;
  final Key? placeholderKey;
  final Key? imageKey;
  final Color? placeholderBackground;

  bool get _hasUrl => url != null && url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final background = placeholderBackground ?? context.appColors.surfaceCard;
    final content = SizedBox(
      width: width,
      height: height,
      child:
          _hasUrl
              ? MaskedImage(key: imageKey, url: url!, fit: fit)
              : DecoratedBox(
                key: placeholderKey,
                decoration: BoxDecoration(color: background),
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: context.appComponentTokens.iconSize2xl,
                  color: context.appTextPalette.muted,
                ),
              ),
    );
    // 底色兜底：`contain` 时图片不满框，留边用底色填充，不露卡片白底。
    return ColoredBox(color: background, child: content);
  }
}
