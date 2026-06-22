import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 移动端骨架占位原子块：纯 surfaceMuted 矩形 + sm 圆角。
class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}

/// 移动端通用骨架卡：卡片壳 + 3 行 [AppSkeletonBlock]。
/// 用于无具体业务装饰需求的列表初次加载占位。
class AppMobileSkeletonCard extends StatelessWidget {
  const AppMobileSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeletonBlock(width: 180, height: 16),
          SizedBox(height: spacing.sm),
          const AppSkeletonBlock(width: double.infinity, height: 12),
          SizedBox(height: spacing.xs),
          const AppSkeletonBlock(width: 220, height: 12),
        ],
      ),
    );
  }
}

/// 移动端列表骨架壳：等距堆叠 [itemCount] 个卡片。
/// 默认渲染 [AppMobileSkeletonCard]；如需自定义卡片样式传 [itemBuilder]。
class AppMobileSkeletonList extends StatelessWidget {
  const AppMobileSkeletonList({
    super.key,
    this.itemCount = 3,
    this.itemBuilder,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final effectivePadding = padding ?? EdgeInsets.all(spacing.md);
    final builder =
        itemBuilder ?? (BuildContext _, int __) => const AppMobileSkeletonCard();
    return Padding(
      padding: effectivePadding,
      child: Column(
        children: List<Widget>.generate(itemCount, (index) {
          final isLast = index == itemCount - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : spacing.sm),
            child: builder(context, index),
          );
        }),
      ),
    );
  }
}
