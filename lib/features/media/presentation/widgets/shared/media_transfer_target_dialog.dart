import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_transfer_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

Future<int?> showMediaTransferTargetDialog(
  BuildContext context, {
  required int selectedCount,
  required MediaTransferCandidatesDto candidates,
}) {
  final body = _MediaTransferTargetDialogBody(
    selectedCount: selectedCount,
    candidates: candidates,
  );
  return showAppAdaptiveModal<int>(
    context: context,
    dialogKey: const Key('media-management-transfer-dialog'),
    drawerKey: const Key('media-management-transfer-drawer'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileMaxHeightFactor: 0.58,
    builder: (_) => body,
  );
}

class _MediaTransferTargetDialogBody extends StatefulWidget {
  const _MediaTransferTargetDialogBody({
    required this.selectedCount,
    required this.candidates,
  });

  final int selectedCount;
  final MediaTransferCandidatesDto candidates;

  @override
  State<_MediaTransferTargetDialogBody> createState() =>
      _MediaTransferTargetDialogBodyState();
}

class _MediaTransferTargetDialogBodyState
    extends State<_MediaTransferTargetDialogBody> {
  late int _targetLibraryId = widget.candidates.targets.first.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mediaListTransferTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Text(
          l10n.mediaListTransferDescription(
            widget.selectedCount,
            widget.candidates.sourceLibrary.name,
          ),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppSelectField<int>(
          key: const Key('media-management-transfer-target-select'),
          label: l10n.mediaListTransferTargetLabel,
          value: _targetLibraryId,
          items: widget.candidates.targets
              .map(
                (target) => DropdownMenuItem<int>(
                  value: target.id,
                  child: Text(target.name),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) setState(() => _targetLibraryId = value);
          },
        ),
        SizedBox(height: spacing.lg),
        Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: context.appColors.warningSurface,
            borderRadius: context.appRadius.mdBorder,
          ),
          child: Text(
            l10n.mediaListTransferNotice,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.warning,
            ),
          ),
        ),
        SizedBox(height: spacing.xl),
        AppModalActionRow(
          cancelKey: const Key('media-management-transfer-cancel-button'),
          submitKey: const Key('media-management-transfer-confirm-button'),
          cancelLabel: l10n.commonCancel,
          submitLabel: l10n.mediaListTransferConfirm,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () => Navigator.of(context).pop(_targetLibraryId),
        ),
      ],
    );
  }
}
