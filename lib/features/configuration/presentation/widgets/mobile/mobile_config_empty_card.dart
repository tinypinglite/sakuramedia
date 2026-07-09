import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 移动端配置页的空态卡壳:`surfaceCard + lgBorder + border` 外框内套
/// [AppEmptyState]。多个 CRUD 页(下载器 / 索引器 / 媒体库)统一形态。
class MobileConfigEmptyCard extends StatelessWidget {
  const MobileConfigEmptyCard({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: AppEmptyState(message: message),
    );
  }
}
