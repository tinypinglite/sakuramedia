import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/system_logs_api.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/system_logs_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class SystemLogExportCard extends ConsumerStatefulWidget {
  const SystemLogExportCard({super.key, required this.isMobile});

  final bool isMobile;

  @override
  ConsumerState<SystemLogExportCard> createState() =>
      _SystemLogExportCardState();
}

class _SystemLogExportCardState extends ConsumerState<SystemLogExportCard> {
  SystemLogRange _range = SystemLogRange.last24Hours;
  bool _redactSensitive = true;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final rangeControl = SizedBox(
      width: 196,
      child: AppSelectField<SystemLogRange>(
        key: const Key('system-logs-range-select'),
        label: l10n.systemLogsRangeLabel,
        value: _range,
        size: AppSelectFieldSize.compact,
        items: _rangeItems(l10n),
        onChanged: _isExporting
            ? null
            : (value) {
                if (value != null) {
                  setState(() => _range = value);
                }
              },
      ),
    );
    final redactControl = _buildRedactControl(l10n);

    return AppContentCard(
      key: const Key('system-logs-export-card'),
      title: l10n.systemLogsExportTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.systemLogsExportDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          if (widget.isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rangeControl,
                SizedBox(height: spacing.md),
                redactControl,
                SizedBox(height: spacing.md),
                _buildExportButton(l10n, expand: true),
              ],
            )
          else
            Wrap(
              spacing: spacing.lg,
              runSpacing: spacing.md,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                rangeControl,
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: context.appFormTokens.compactFieldHeight,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: redactControl,
                  ),
                ),
                _buildExportButton(l10n),
              ],
            ),
          SizedBox(height: spacing.sm),
          Text(
            _redactSensitive
                ? l10n.systemLogsRedactDescription
                : l10n.systemLogsRawWarning,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: _redactSensitive ? AppTextTone.muted : AppTextTone.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedactControl(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.systemLogsRedactLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppSwitch(
          key: const Key('system-logs-redact-switch'),
          value: _redactSensitive,
          onChanged: _isExporting
              ? null
              : (value) => setState(() => _redactSensitive = value),
        ),
      ],
    );
  }

  Widget _buildExportButton(AppLocalizations l10n, {bool expand = false}) {
    final button = AppButton(
      key: const Key('system-logs-export-button'),
      label: l10n.systemLogsExportAction,
      variant: AppButtonVariant.primary,
      size: widget.isMobile ? AppButtonSize.medium : AppButtonSize.small,
      icon: const Icon(Icons.download_outlined),
      isLoading: _isExporting,
      onPressed: _isExporting ? null : () => unawaited(_export(l10n)),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  List<DropdownMenuItem<SystemLogRange>> _rangeItems(AppLocalizations l10n) {
    return <DropdownMenuItem<SystemLogRange>>[
      DropdownMenuItem(
        value: SystemLogRange.lastHour,
        child: Text(l10n.systemLogsRangeLastHour),
      ),
      DropdownMenuItem(
        value: SystemLogRange.last24Hours,
        child: Text(l10n.systemLogsRangeLast24Hours),
      ),
      DropdownMenuItem(
        value: SystemLogRange.last7Days,
        child: Text(l10n.systemLogsRangeLast7Days),
      ),
      DropdownMenuItem(
        value: SystemLogRange.last30Days,
        child: Text(l10n.systemLogsRangeLast30Days),
      ),
    ];
  }

  Future<void> _export(AppLocalizations l10n) async {
    if (_isExporting) {
      return;
    }
    if (!_redactSensitive) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.systemLogsRawConfirmTitle,
        message: l10n.systemLogsRawConfirmMessage,
        confirmLabel: l10n.systemLogsRawConfirmAction,
        danger: true,
        dialogKey: const Key('system-logs-raw-confirm-dialog'),
        confirmKey: const Key('system-logs-raw-confirm'),
        cancelKey: const Key('system-logs-raw-cancel'),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _isExporting = true);
    try {
      final bytes = await ref
          .read(systemLogsApiProvider)
          .downloadArchive(range: _range, redactSensitive: _redactSensitive);
      final savedUri = await FilePicker.saveFile(
        dialogTitle: l10n.systemLogsSaveDialogTitle,
        fileName: _archiveFileName(),
        bytes: bytes,
        mimeType: 'application/zip',
      );
      if (mounted && savedUri != null) {
        showToast(l10n.systemLogsExportSuccess);
      }
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.systemLogsExportFailed,
            l10n: l10n,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _archiveFileName() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}-'
        '${twoDigits(now.hour)}${twoDigits(now.minute)}'
        '${twoDigits(now.second)}';
    return 'sakuramedia-logs-${_range.apiValue}-$timestamp.zip';
  }
}
