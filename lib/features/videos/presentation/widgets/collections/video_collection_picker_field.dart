import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

/// 「加入合集」只读选择条：外观对齐 `AppSelectField`，点击打开可搜索单选弹层。
///
/// 下载手动添加与视频导入共用。名称由调用方解析后通过 [valueLabel] 传入，
/// 本组件不订阅 provider，避免两个 feature 各自复制一套 provider 装配。
class VideoCollectionPickerField extends StatelessWidget {
  const VideoCollectionPickerField({
    super.key,
    required this.valueLabel,
    required this.onTap,
    this.onCreate,
    this.enabled = true,
    this.fieldKey,
    this.createButtonKey,
  });

  /// 已选合集名；null/空显示「不加入合集」。
  final String? valueLabel;

  final VoidCallback onTap;

  /// 新建合集入口；null 时不渲染按钮。
  final VoidCallback? onCreate;

  final bool enabled;

  /// 触发条的测试 Key。
  final Key? fieldKey;

  /// 「新建合集」按钮的测试 Key。
  final Key? createButtonKey;

  @override
  Widget build(BuildContext context) {
    final formTokens = context.appFormTokens;
    final l10n = AppLocalizations.of(context);
    final label = valueLabel?.trim() ?? '';
    final canCreate = onCreate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.videoAddToCollectionOptional,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
            const Spacer(),
            if (canCreate)
              AppTextButton(
                key: createButtonKey,
                label: l10n.videoNewCollection,
                size: AppTextButtonSize.small,
                onPressed: enabled ? onCreate : null,
              ),
          ],
        ),
        SizedBox(height: formTokens.labelGap),
        AppInteractiveSurface(
          key: fieldKey,
          enabled: enabled,
          onTap: enabled ? onTap : null,
          focusRingRadius: context.appRadius.smBorder,
          child: AppSurface(
            width: double.infinity,
            borderRadius: context.appRadius.smBorder,
            role: AppSurfaceRole.control,
            padding: EdgeInsets.symmetric(
              horizontal: formTokens.fieldHorizontalPadding,
              vertical: formTokens.fieldVerticalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.isEmpty ? l10n.videoNoCollection : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: label.isEmpty
                          ? AppTextTone.muted
                          : AppTextTone.primary,
                    ),
                  ),
                ),
                SizedBox(width: context.appSpacing.sm),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                  color: context.appTextPalette.secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
