import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 播放器菜单 / 抽屉里的一行:左侧 label + 右侧勾选槽。
///
/// 四处逐字相同的骨架合并到此:
///   - 桌面 speed 菜单项 (movie_player_speed_button)
///   - 桌面 subtitle 菜单项 (movie_player_subtitle_button)
///   - 移动 speed 抽屉项 (movie_player_surface)
///   - 移动 subtitle 抽屉项 (movie_player_surface)
///
/// label overflow / 勾选色由参数保真；subtitle 需 `overflow: ellipsis`，
/// speed 无。浮层行统一用主题文字色，只有播放器触发按钮使用媒体白字。
class MoviePlayerMenuItemRow extends StatelessWidget {
  const MoviePlayerMenuItemRow({
    super.key,
    required this.label,
    required this.selected,
    required this.checkColor,
    this.labelKey,
    this.checkKey,
    this.checkSlotKey,
    this.overflow,
    this.maxLines,
    this.background,
    this.trailing,
    this.labelTone = AppTextTone.primary,
  });

  final String label;
  final bool selected;

  /// 选中时勾选 icon 与文字 accent 色。
  final Color checkColor;

  final Key? labelKey;
  final Key? checkKey;
  final Key? checkSlotKey;

  /// subtitle 传 [TextOverflow.ellipsis]。
  final TextOverflow? overflow;

  /// subtitle 传 1。
  final int? maxLines;

  /// 可选 hover 状态背景色；默认不画底色。
  final Color? background;

  /// 勾选槽位的替代尾部内容，例如设置行的右箭头。
  final Widget? trailing;

  /// 未选中行的文字色；播放器浮层使用主题 `primary`，不要用媒体白字。
  final AppTextTone labelTone;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return SizedBox(
      height: overlayTokens.menuItemHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background),
        child: Row(
          children: [
            SizedBox(width: overlayTokens.controlSideGap),
            Expanded(
              child: Text(
                label,
                key: labelKey,
                overflow: overflow,
                maxLines: maxLines,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: selected ? AppTextTone.accent : labelTone,
                ),
              ),
            ),
            if (trailing != null)
              SizedBox(
                width: overlayTokens.controlCheckSlotWidth,
                child: Center(child: trailing),
              )
            else
              SizedBox(
                width: overlayTokens.controlCheckSlotWidth,
                child: Center(
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          key: checkKey,
                          size: overlayTokens.controlCheckIconSize,
                          color: checkColor,
                        )
                      : SizedBox(
                          key: checkSlotKey,
                          width: overlayTokens.controlCheckIconSize,
                          height: overlayTokens.controlCheckIconSize,
                        ),
                ),
              ),
            SizedBox(width: overlayTokens.controlTrailingGap),
          ],
        ),
      ),
    );
  }
}
