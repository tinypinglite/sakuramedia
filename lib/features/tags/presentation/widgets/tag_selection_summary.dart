import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 标签页结果态的选择摘要：已选标签、匹配模式和「修改标签」入口。
///
/// 选择本身在浏览态完成；这里只展示已应用的选择，并把修改动作交回页面。
class TagSelectionSummary extends ConsumerWidget {
  const TagSelectionSummary({
    super.key,
    required this.scope,
    required this.mobile,
    required this.onEdit,
    required this.onRemoveTag,
    required this.onClear,
  });

  final TagSelectionScope scope;
  final bool mobile;
  final VoidCallback onEdit;
  final ValueChanged<int> onRemoveTag;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(tagSelectionProvider(scope));
    final notifier = ref.read(tagSelectionProvider(scope).notifier);
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final editButton = AppTextButton(
      key: const Key('tags-edit-selection'),
      label: selection.hasSelection
          ? l10n.tagSummarySelected(selection.selectedCount)
          : l10n.tagSummarySelect,
      trailingIcon: const Icon(Icons.tune_rounded),
      size: AppTextButtonSize.small,
      isSelected: selection.hasSelection,
      onPressed: onEdit,
    );
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final tag in selection.selectedTags)
            AppTextButton(
              key: Key('tags-summary-${tag.tagId}'),
              label: tag.name,
              trailingIcon: const Icon(Icons.close),
              size: AppTextButtonSize.xSmall,
              onPressed: () => onRemoveTag(tag.tagId),
            ),
          AppTextButton(
            key: const Key('tags-summary-clear'),
            label: l10n.tagClear,
            size: AppTextButtonSize.xSmall,
            onPressed: onClear,
          ),
        ],
      ),
    );
    final matchToggle = AppTextButton(
      key: const Key('tags-summary-match'),
      label: l10n.tagSummaryMatchMode(selection.matchMode.labelWith(l10n)),
      size: AppTextButtonSize.xSmall,
      onPressed: () => notifier.setMatchMode(
        selection.matchMode == TagMatchMode.or
            ? TagMatchMode.and
            : TagMatchMode.or,
      ),
    );

    if (mobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(children: <Widget>[editButton, const Spacer(), matchToggle]),
            if (selection.hasSelection) ...<Widget>[
              SizedBox(height: spacing.sm),
              chips,
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Row(
        children: <Widget>[
          editButton,
          if (selection.hasSelection) ...<Widget>[
            SizedBox(width: spacing.sm),
            Expanded(child: chips),
            matchToggle,
          ],
        ],
      ),
    );
  }
}
