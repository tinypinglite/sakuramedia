import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

Future<MediaTagDto?> showMediaTagRuleEditor(
  BuildContext context, {
  required bool mobile,
  MediaTagDto? initialTag,
}) async {
  final dismissController = AppModalDismissController();
  try {
    return await showAppAdaptiveModal<MediaTagDto>(
      context: context,
      variant: mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      dialogKey: const Key('media-tag-rule-editor-dialog'),
      drawerKey: const Key('media-tag-rule-editor-drawer'),
      desktopConstraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
      mobileHeightFactor: 0.88,
      dismissController: dismissController,
      builder: (_) => _MediaTagRuleEditor(
        initialTag: initialTag,
        dismissController: dismissController,
      ),
    );
  } finally {
    dismissController.dispose();
  }
}

class _MediaTagRuleEditor extends ConsumerStatefulWidget {
  const _MediaTagRuleEditor({this.initialTag, this.dismissController});

  final MediaTagDto? initialTag;
  final AppModalDismissController? dismissController;

  @override
  ConsumerState<_MediaTagRuleEditor> createState() =>
      _MediaTagRuleEditorState();
}

class _MediaTagRuleEditorState extends ConsumerState<_MediaTagRuleEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _includeController;
  late final TextEditingController _excludeController;
  late bool _enabled;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialTag != null;

  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final tag = widget.initialTag;
    _nameController = TextEditingController(text: tag?.name ?? '');
    _includeController = TextEditingController(
      text: tag?.includeTerms.join('\n') ?? '',
    );
    _excludeController = TextEditingController(
      text: tag?.excludeTerms.join('\n') ?? '',
    );
    _enabled = tag?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _includeController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  List<String> _parseTerms(TextEditingController controller) {
    final result = <String>[];
    final seen = <String>{};
    for (final line in controller.text.split(RegExp(r'\r?\n'))) {
      final term = line.trim();
      if (term.isEmpty) continue;
      if (seen.add(term.toLowerCase())) {
        result.add(term);
      }
    }
    return result;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _hasAttemptedSubmit = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final payload = MediaTagUpsertPayload(
      name: _nameController.text,
      includeTerms: _parseTerms(_includeController),
      excludeTerms: _parseTerms(_excludeController),
      enabled: _enabled,
    );
    widget.dismissController?.setLocked(true);
    setState(() => _isSubmitting = true);
    try {
      final notifier = ref.read(mediaTagsProvider.notifier);
      final saved = _isEditing
          ? await notifier.updateTag(
              tagId: widget.initialTag!.id,
              payload: payload,
            )
          : await notifier.create(payload);
      if (!mounted) return;
      showToast(
        _isEditing ? l10n.mediaTagsSaved : l10n.mediaTagsCreated,
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing
              ? l10n.mediaTagsSaveFailed
              : l10n.mediaTagsCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
      widget.dismissController?.setLocked(false);
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        key: const Key('media-tag-rule-editor'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? l10n.mediaTagsEditTitle : l10n.mediaTagsAdd,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    fieldKey: const Key('media-tag-name-field'),
                    controller: _nameController,
                    label: l10n.mediaTagsNameLabel,
                    hintText: l10n.mediaTagsNameHint,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: _autovalidateMode,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.mediaTagsNameRequired
                        : null,
                  ),
                  SizedBox(height: spacing.lg),
                  AppTextField(
                    fieldKey: const Key('media-tag-include-terms-field'),
                    controller: _includeController,
                    label: l10n.mediaTagsIncludeTermsLabel,
                    hintText: l10n.mediaTagsIncludeTermsHint,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 4,
                    maxLines: 8,
                    autovalidateMode: _autovalidateMode,
                    validator: (_) => _parseTerms(_includeController).isEmpty
                        ? l10n.mediaTagsIncludeTermsRequired
                        : null,
                  ),
                  SizedBox(height: spacing.lg),
                  AppTextField(
                    fieldKey: const Key('media-tag-exclude-terms-field'),
                    controller: _excludeController,
                    label: l10n.mediaTagsExcludeTermsLabel,
                    hintText: l10n.mediaTagsExcludeTermsHint,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 3,
                    maxLines: 6,
                  ),
                  SizedBox(height: spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.mediaTagsEnabledLabel,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                tone: AppTextTone.primary,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              l10n.mediaTagsEnabledDescription,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s12,
                                tone: AppTextTone.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      AppSwitch(
                        key: const Key('media-tag-enabled-switch'),
                        value: _enabled,
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _enabled = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          AppModalActionRow(
            submitLabel: l10n.commonSave,
            submitKey: const Key('media-tag-rule-save'),
            isSubmitting: _isSubmitting,
            showCancel: false,
            equalWidth: AppAdaptiveModalShellScope.maybeIsDrawer(context),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
