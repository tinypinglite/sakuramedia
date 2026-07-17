import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// media feature 内部的通用封面缩略图：ClipRRect + fixed size + placeholder/MaskedImage。
///
/// 之前分散在 `media_list_pane._MediaCover` 与 `desktop_media_maintenance_page._InvalidMediaCover`
/// 两份几乎照抄的实现里，合并到本文件；双端可用（尺寸由调用方传，跟随 layout token）。
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
    return ClipRRect(
      borderRadius: context.appRadius.mdBorder,
      child: SizedBox(
        width: width,
        height: height,
        child: _hasUrl
            ? MaskedImage(key: imageKey, url: url!, fit: fit)
            : DecoratedBox(
                key: placeholderKey,
                decoration: BoxDecoration(
                  color: placeholderBackground ?? context.appColors.surfaceCard,
                ),
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: context.appComponentTokens.iconSize2xl,
                  color: context.appTextPalette.muted,
                ),
              ),
      ),
    );
  }
}
