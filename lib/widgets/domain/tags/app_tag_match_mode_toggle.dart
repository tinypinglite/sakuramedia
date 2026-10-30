import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 「任一 / 全部」匹配模式切换按钮组。
///
/// 目录标签筛选（[TagSelectorPanel]）与媒体文件标签筛选共用这一组按钮，
/// 避免两处各写一份、交互与间距慢慢漂移。
class AppTagMatchModeToggle extends StatelessWidget {
  const AppTagMatchModeToggle({
    super.key,
    required this.matchMode,
    required this.onChanged,
    this.buttonKeyPrefix,
  });

  final TagMatchMode matchMode;
  final ValueChanged<TagMatchMode> onChanged;

  /// 按钮 Key 前缀；不同筛选分节需要各自的 Key 时传入。
  final String? buttonKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in TagMatchMode.values) ...[
          AppTextButton(
            key: buttonKeyPrefix == null
                ? null
                : Key('$buttonKeyPrefix-${mode.name}'),
            label: mode.labelWith(l10n),
            size: AppTextButtonSize.xSmall,
            isSelected: matchMode == mode,
            onPressed: () => onChanged(mode),
          ),
          if (mode != TagMatchMode.values.last)
            SizedBox(width: spacing.sm),
        ],
      ],
    );
  }
}
