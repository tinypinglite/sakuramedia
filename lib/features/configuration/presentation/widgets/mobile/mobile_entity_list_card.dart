import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// configuration 三个移动页面（indexers / downloaders / media_libraries）
/// 共用的实体列表卡片外壳。
///
/// 内部 shell 完全对齐三份已有 `_MobileXxxCard`：
/// - Container(outer decoration: surfaceCard + lgBorder + borderSubtle)
///   → Row [
///       Expanded(Material transparent → InkWell(bodyKey, onTap) → Padding(md) → Row [ leading, md, Expanded(Column [ Row[title + titleTrailing], ...body ]) ]),
///       optional trailingAction（InkWell 之外的独立按钮，如 media_libraries 的更多按钮）
///     ]
///
/// 三份卡片的 body slot 内部结构差异较大（downloader 有探针 chips + 警告块，
/// indexer 有 kindBadge + 绑定失效提示，media_library 结构简单还带独立 more
/// button），所以 body 由调用方组装。等 subscriptions / moments 等其他 feature
/// 用到时，再决定是否上抬 `lib/widgets/`。
class MobileEntityListCard extends StatelessWidget {
  const MobileEntityListCard({
    super.key,
    this.outerKey,
    this.bodyKey,
    required this.leading,
    required this.title,
    this.titleTrailing,
    required this.body,
    required this.onTap,
    this.trailingAction,
  });

  final Key? outerKey;
  final Key? bodyKey;
  final Widget leading;
  final Widget title;
  final Widget? titleTrailing;
  final List<Widget> body;
  final VoidCallback onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            if (titleTrailing != null) ...[
              SizedBox(width: spacing.sm),
              titleTrailing!,
            ],
          ],
        ),
        ...body,
      ],
    );

    final tapArea = Material(
      color: Colors.transparent,
      child: AppInteractiveSurface(
        key: bodyKey,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              SizedBox(width: spacing.md),
              Expanded(child: infoColumn),
            ],
          ),
        ),
      ),
    );

    return AppContentCard(
      key: outerKey,
      title: null,
      padding: EdgeInsets.zero,
      child: trailingAction == null
          ? tapArea
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tapArea),
                Padding(
                  padding: EdgeInsets.only(top: spacing.sm, right: spacing.sm),
                  child: trailingAction,
                ),
              ],
            ),
    );
  }
}
