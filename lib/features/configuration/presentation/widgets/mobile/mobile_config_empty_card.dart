import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 移动端配置页的空态卡壳:`surfaceCard + lgBorder + border` 外框内套
/// [AppEmptyState]。多个 CRUD 页(下载器 / 索引器 / 媒体库)统一形态。
class MobileConfigEmptyCard extends StatelessWidget {
  const MobileConfigEmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      child: AppEmptyState(message: message),
    );
  }
}
