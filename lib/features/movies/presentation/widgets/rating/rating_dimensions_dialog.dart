import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/rating/rating_dimension_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/rating_dimensions_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

Future<void> showRatingDimensionsDialog(
  BuildContext context, {
  required WidgetRef ref,
}) {
  // has_scores 由评分数据派生；打开管理面板时重新拉取，避免范围被错误锁定或放开。
  ref.invalidate(ratingDimensionsProvider);
  return showAppAdaptiveModal<void>(
    context: context,
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.9,
    builder: (_) => const RatingDimensionsDialog(),
  );
}

/// 评分维度管理：名称 + 分值范围；权重暂不开放编辑。
class RatingDimensionsDialog extends ConsumerStatefulWidget {
  const RatingDimensionsDialog({super.key});

  @override
  ConsumerState<RatingDimensionsDialog> createState() =>
      _RatingDimensionsDialogState();
}

class _RatingDimensionsDialogState
    extends ConsumerState<RatingDimensionsDialog> {
  final _nameController = TextEditingController();

  int? _editingId;
  double _editingWeight = 1;
  int _editingMaxValue = 5;
  bool _editingHasScores = false;
  bool _showForm = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startCreate() {
    setState(() {
      _editingId = null;
      _editingWeight = 1;
      _editingMaxValue = 5;
      _editingHasScores = false;
      _showForm = true;
      _nameController.clear();
    });
  }

  void _startEdit(RatingDimensionDto dimension) {
    setState(() {
      _editingId = dimension.id;
      _editingWeight = dimension.weight;
      _editingMaxValue = dimension.maxValue;
      _editingHasScores = dimension.hasScores;
      _showForm = true;
      _nameController.text = dimension.name;
    });
  }

  void _cancelForm() {
    setState(() {
      _showForm = false;
      _editingId = null;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(
        AppLocalizations.of(context).movieWidgetDimensionNameRequired,
        tone: AppToastTone.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final notifier = ref.read(ratingDimensionsProvider.notifier);
      if (_editingId == null) {
        await notifier.create(name: name, maxValue: _editingMaxValue);
      } else {
        await notifier.edit(
          dimensionId: _editingId!,
          name: name,
          // 权重暂不开放编辑，但编辑其它字段时不能把已有权重重置为默认值。
          weight: _editingWeight,
          maxValue: _editingHasScores ? null : _editingMaxValue,
        );
      }
      if (!mounted) return;
      setState(() {
        _showForm = false;
        _editingId = null;
      });
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieWidgetRatingDimensionSaveFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(RatingDimensionDto dimension) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.movieWidgetDeleteRatingDimensionTitle,
      message: l10n.movieWidgetDeleteRatingDimensionMessage(dimension.name),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(ratingDimensionsProvider.notifier).delete(dimension.id);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieWidgetRatingDimensionDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = ref.watch(ratingDimensionsProvider);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.movieWidgetRatingDimensionsTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          l10n.movieWidgetRatingScaleHint,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.md),
        if (dimensions.isLoading && !dimensions.hasValue)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.appSpacing.xl),
            child: const Center(child: AppInlineSpinner()),
          )
        else if (dimensions.hasError && !dimensions.hasValue)
          AppErrorState.inline(
            message: l10n.movieWidgetRatingDimensionsLoadFailed,
            onRetry: () => ref.invalidate(ratingDimensionsProvider),
          )
        else
          _buildDimensionBlock(
            context,
            dimensions.value ?? const <RatingDimensionDto>[],
          ),
        if (_showForm) ...[
          SizedBox(height: context.appSpacing.md),
          _buildForm(context),
        ],
      ],
    );
  }

  Widget _buildDimensionBlock(
    BuildContext context,
    List<RatingDimensionDto> dimensions,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        children: [
          for (final dimension in dimensions) ...[
            _buildDimensionRow(context, dimension),
            Padding(
              padding: EdgeInsets.only(left: context.appSpacing.lg),
              child: Divider(
                height: 1,
                thickness: 1,
                color: context.appColors.borderSubtle,
              ),
            ),
          ],
          AppInteractiveSurface(
            key: const Key('rating-dimension-add'),
            onTap: _startCreate,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.appSpacing.lg,
                vertical: context.appSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: context.appTextPalette.accent,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    l10n.movieWidgetAddDimension,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionRow(
    BuildContext context,
    RatingDimensionDto dimension,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key('rating-dimension-${dimension.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.lg,
        vertical: context.appSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dimension.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(context, size: AppTextSize.s14),
                ),
                SizedBox(height: context.appSpacing.xs / 2),
                Text(
                  '${dimension.minValue}–${dimension.maxValue}',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            size: AppIconButtonSize.mini,
            onPressed: () => _startEdit(dimension),
          ),
          AppIconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.commonDelete,
            size: AppIconButtonSize.mini,
            onPressed: () => _delete(dimension),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _editingId == null
              ? l10n.movieWidgetAddDimension
              : l10n.movieWidgetEditDimension,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        AppTextField(
          fieldKey: const Key('rating-dimension-name-field'),
          controller: _nameController,
          hintText: l10n.movieWidgetDimensionNameHint,
        ),
        SizedBox(height: context.appSpacing.md),
        Text(
          l10n.movieWidgetRatingScaleLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Opacity(
          opacity: _editingHasScores ? 0.5 : 1,
          child: IgnorePointer(
            ignoring: _editingHasScores,
            child: AppSegmentedControl<int>(
              key: const Key('rating-dimension-scale-control'),
              items: [
                for (final maxValue in const [5, 10, 100])
                  AppSegmentedItem<int>(
                    value: maxValue,
                    label: _ratingScaleLabel(maxValue, l10n),
                    key: Key('rating-dimension-scale-$maxValue'),
                  ),
              ],
              selected: _editingMaxValue,
              size: AppSegmentedSize.compact,
              onChanged: (value) => setState(() => _editingMaxValue = value),
            ),
          ),
        ),
        if (_editingHasScores) ...[
          SizedBox(height: context.appSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: context.appComponentTokens.iconSize2xs,
                color: context.appTextPalette.muted,
              ),
              SizedBox(width: context.appSpacing.xs),
              Expanded(
                child: Text(
                  l10n.movieWidgetRatingScaleLocked,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: context.appSpacing.md),
        AppModalActionRow(
          cancelLabel: l10n.commonCancel,
          submitLabel: l10n.commonSave,
          isSubmitting: _saving,
          onCancel: _cancelForm,
          onSubmit: _save,
        ),
      ],
    );
  }
}

String _ratingScaleLabel(int maxValue, AppLocalizations l10n) {
  return switch (maxValue) {
    10 => l10n.movieWidgetRatingScale10,
    100 => l10n.movieWidgetRatingScale100,
    _ => l10n.movieWidgetRatingScale5,
  };
}
