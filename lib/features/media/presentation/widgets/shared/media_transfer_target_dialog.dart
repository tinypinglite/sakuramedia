import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/media/data/media_transfer_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<int?> showMediaTransferTargetDialog(
  BuildContext context, {
  required int selectedCount,
  required MediaTransferCandidatesDto candidates,
}) {
  final body = _MediaTransferTargetDialogBody(
    selectedCount: selectedCount,
    candidates: candidates,
  );
  if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
    return showAppBottomDrawer<int>(
      context: context,
      drawerKey: const Key('media-management-transfer-drawer'),
      maxHeightFactor: 0.58,
      builder: (_) => body,
    );
  }
  return showAppDialog<int>(
    context: context,
    builder: (_) => AppDesktopDialog(
      dialogKey: const Key('media-management-transfer-dialog'),
      width: context.appLayoutTokens.dialogWidthSm,
      child: body,
    ),
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
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('media-management-transfer-cancel-button'),
                label: l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('media-management-transfer-confirm-button'),
                label: l10n.mediaListTransferConfirm,
                variant: AppButtonVariant.danger,
                icon: const Icon(Icons.drive_file_move_outline),
                onPressed: () => Navigator.of(context).pop(_targetLibraryId),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
