import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<DownloadSelectionKeywordGroupDto?>
showDownloadSelectionKeywordGroupEditor(
  BuildContext context, {
  required String title,
  DownloadSelectionKeywordGroupDto? initialGroup,
}) {
  return showAppAdaptiveModal<DownloadSelectionKeywordGroupDto>(
    context: context,
    modalKey: const Key('download-selection-keyword-group-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    mobileHeightFactor: 0.72,
    builder: (_) => _DownloadSelectionKeywordGroupEditor(
      title: title,
      initialGroup: initialGroup,
    ),
  );
}

class _DownloadSelectionKeywordGroupEditor extends StatefulWidget {
  const _DownloadSelectionKeywordGroupEditor({
    required this.title,
    this.initialGroup,
  });

  final String title;
  final DownloadSelectionKeywordGroupDto? initialGroup;

  @override
  State<_DownloadSelectionKeywordGroupEditor> createState() =>
      _DownloadSelectionKeywordGroupEditorState();
}

class _DownloadSelectionKeywordGroupEditorState
    extends State<_DownloadSelectionKeywordGroupEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _termsController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.initialGroup?.label ?? '',
    );
    _termsController = TextEditingController(
      text: widget.initialGroup?.terms.join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  List<String> _parseTerms() {
    final seen = <String>{};
    final terms = <String>[];
    for (final line in _termsController.text.split(RegExp(r'\r?\n'))) {
      final term = line.trim();
      final key = term.toLowerCase();
      if (term.isEmpty || !seen.add(key)) continue;
      terms.add(term);
    }
    return terms;
  }

  String? _validateTerms(String? value) {
    if (_parseTerms().isEmpty) {
      return AppLocalizations.of(context).downloadSelectionTermsRequired;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final label = _labelController.text.trim();
    Navigator.of(context).pop(
      DownloadSelectionKeywordGroupDto(
        label: label.isEmpty ? null : label,
        terms: _parseTerms(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.downloadSelectionKeywordGroupEditorHint,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    fieldKey: const Key(
                      'download-selection-keyword-group-label',
                    ),
                    controller: _labelController,
                    label: l10n.downloadSelectionKeywordGroupLabel,
                    hintText: l10n.downloadSelectionKeywordGroupLabelHint,
                    maxLines: 1,
                  ),
                  SizedBox(height: spacing.md),
                  AppTextField(
                    fieldKey: const Key(
                      'download-selection-keyword-group-terms',
                    ),
                    controller: _termsController,
                    label: l10n.downloadSelectionTermsLabel,
                    hintText: l10n.downloadSelectionTermsHint,
                    helperText: l10n.downloadSelectionTermsHelper,
                    minLines: 5,
                    maxLines: 9,
                    validator: _validateTerms,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('download-selection-keyword-group-cancel'),
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: AppButton(
                  key: const Key('download-selection-keyword-group-save'),
                  label: l10n.commonSave,
                  variant: AppButtonVariant.primary,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
