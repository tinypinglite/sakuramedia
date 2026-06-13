import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/person_selection_controller.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// 人物多选区：搜索框 + 已选人物 chips + 搜索/热门结果。与标签面板形态对齐，
/// 但人物来自分页搜索接口，故结果区直接展示当前查询的一页。
class PersonSelectorPanel extends StatefulWidget {
  const PersonSelectorPanel({
    super.key,
    required this.selection,
    required this.onTogglePerson,
    required this.onRemovePerson,
    required this.onClear,
    required this.onQueryChanged,
    required this.onRetry,
  });

  final PersonSelectionController selection;
  final ValueChanged<PersonDto> onTogglePerson;
  final ValueChanged<int> onRemovePerson;
  final VoidCallback onClear;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onRetry;

  @override
  State<PersonSelectorPanel> createState() => _PersonSelectorPanelState();
}

class _PersonSelectorPanelState extends State<PersonSelectorPanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.selection.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final spacing = context.appSpacing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选择人物',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
              if (selection.hasSelection) ...[
                Text(
                  '已选 ${selection.selectedCount} 人',
                  key: const Key('persons-selected-count'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(width: spacing.sm),
                AppTextButton(
                  label: '清空',
                  size: AppTextButtonSize.xSmall,
                  onPressed: widget.onClear,
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('persons-search-field'),
            controller: _searchController,
            hintText: '搜索人物',
            prefix: Icon(
              Icons.search,
              size: context.appComponentTokens.iconSizeSm,
              color: context.appTextPalette.secondary,
            ),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      size: context.appComponentTokens.iconSizeSm,
                    ),
                    splashRadius: 16,
                    onPressed: () {
                      _searchController.clear();
                      widget.onQueryChanged('');
                    },
                  ),
            onChanged: widget.onQueryChanged,
          ),
          if (selection.hasSelection) ...[
            SizedBox(height: spacing.md),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final person in selection.selectedPersons)
                  AppTextButton(
                    key: Key('persons-selected-chip-${person.id}'),
                    label: '${person.name} ✕',
                    size: AppTextButtonSize.xSmall,
                    isSelected: true,
                    onPressed: () => widget.onRemovePerson(person.id),
                  ),
              ],
            ),
          ],
          SizedBox(height: spacing.md),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final selection = widget.selection;
    if (selection.isLoading && !selection.hasLoadedOnce) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final error = selection.errorMessage;
    if (error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            label: '重试',
            size: AppTextButtonSize.xSmall,
            onPressed: widget.onRetry,
          ),
        ],
      );
    }
    if (selection.results.isEmpty) {
      return Text(
        selection.isSearching ? '未找到匹配的人物' : '暂无人物',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      );
    }
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        for (final person in selection.results)
          AppTextButton(
            key: Key('persons-result-chip-${person.id}'),
            label: person.videoCount > 0
                ? '${person.name} (${person.videoCount})'
                : person.name,
            size: AppTextButtonSize.xSmall,
            isSelected: selection.isSelected(person.id),
            onPressed: () => widget.onTogglePerson(person),
          ),
      ],
    );
  }
}
