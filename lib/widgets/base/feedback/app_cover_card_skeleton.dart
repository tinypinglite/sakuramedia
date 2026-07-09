import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 封面卡骨架 = 圆角 Container(surfaceCard) + 可选 AspectRatio + surfaceMuted 内框。
///
/// movie / actor / rankedMovie / video 四份网格 skeleton 复用它。
/// 传 [aspectRatio] 时内层裹 [AspectRatio](movie / actor / rankedMovie 走
/// `movieCardAspectRatio`);不传时直接把整块灰色内框铺满 Container
/// (video masonry 布局无固定长宽比)。
class AppCoverCardSkeleton extends StatelessWidget {
  const AppCoverCardSkeleton({
    super.key,
    this.posterKey,
    this.aspectRatio,
  });

  final Key? posterKey;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final poster = DecoratedBox(
      key: posterKey,
      decoration: BoxDecoration(color: context.appColors.surfaceMuted),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: aspectRatio == null
          ? poster
          : AspectRatio(aspectRatio: aspectRatio!, child: poster),
    );
  }
}
