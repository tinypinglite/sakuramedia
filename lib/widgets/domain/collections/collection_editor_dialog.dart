import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

enum CollectionEditorPresentation { dialog, drawer, bottomFormSheet, adaptive }

enum CollectionEditorHeaderStyle { plain, strong, edit }

class CollectionEditorCopy {
  const CollectionEditorCopy({
    required this.title,
    required this.nameHint,
    required this.descriptionHint,
    required this.nameRequiredMessage,
    required this.submitLabel,
  });

  final String title;
  final String nameHint;
  final String descriptionHint;
  final String nameRequiredMessage;
  final String submitLabel;
}

class CollectionEditorConfig<T> {
  const CollectionEditorConfig({
    required this.presentation,
    required this.keyPrefix,
    required this.copy,
    required this.initialName,
    required this.initialDescription,
    required this.errorFallback,
    required this.onSubmit,
    this.headerStyle = CollectionEditorHeaderStyle.plain,
    this.descriptionMaxLines = 1,
    this.descriptionMinLines = 1,
    this.autovalidateAfterSubmit = false,
    this.unfocusOnSubmit = false,
    this.dialogWidth,
    this.drawerKey,
    this.drawerMaxHeightFactor = 0.62,
    this.onSuccess,
  });

  final CollectionEditorPresentation presentation;
  final String keyPrefix;
  final CollectionEditorCopy copy;
  final String initialName;
  final String initialDescription;
  final String Function(AppLocalizations l10n) errorFallback;
  final Future<T> Function(WidgetRef ref, String name, String description)
  onSubmit;
  final CollectionEditorHeaderStyle headerStyle;
  final int descriptionMaxLines;
  final int descriptionMinLines;
  final bool autovalidateAfterSubmit;
  final bool unfocusOnSubmit;
  final double? dialogWidth;
  final Key? drawerKey;
  final double drawerMaxHeightFactor;
  final void Function(BuildContext context, T result)? onSuccess;

  Key get nameFieldKey => Key('$keyPrefix-name-field');
  Key get descriptionFieldKey => Key('$keyPrefix-description-field');
  Key get submitKey => Key('$keyPrefix-submit-button');
}

Future<T?> showCollectionEditor<T>(
  BuildContext context, {
  required CollectionEditorConfig<T> config,
}) {
  switch (config.presentation) {
    case CollectionEditorPresentation.dialog:
      return showAppDialog<T>(
        context: context,
        builder: (_) => CollectionEditorDialog<T>(config: config),
      );
    case CollectionEditorPresentation.drawer:
      return showAppBottomDrawer<T>(
        context: context,
        drawerKey: config.drawerKey,
        maxHeightFactor: config.drawerMaxHeightFactor,
        builder: (_) => SingleChildScrollView(
          child: CollectionEditorDialog<T>(config: config),
        ),
      );
    case CollectionEditorPresentation.bottomFormSheet:
      return showAppBottomDrawer<T>(
        context: context,
        drawerKey: config.drawerKey,
        maxHeightFactor: config.drawerMaxHeightFactor,
        builder: (_) => CollectionEditorDialog<T>(config: config),
      );
    case CollectionEditorPresentation.adaptive:
      return showAppAdaptiveModal<T>(
        context: context,
        drawerKey: config.drawerKey,
        desktopWidth: config.dialogWidth,
        mobileMaxHeightFactor: config.drawerMaxHeightFactor,
        builder: (_) => SingleChildScrollView(
          child: CollectionEditorDialog<T>(config: config),
        ),
      );
  }
}

class CollectionEditorDialog<T> extends ConsumerStatefulWidget {
  const CollectionEditorDialog({super.key, required this.config});

  final CollectionEditorConfig<T> config;

  @override
  ConsumerState<CollectionEditorDialog<T>> createState() =>
      _CollectionEditorDialogState<T>();
}

class _CollectionEditorDialogState<T>
    extends ConsumerState<CollectionEditorDialog<T>> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final AppModalDismissController _dismissController =
      AppModalDismissController();
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;

  CollectionEditorConfig<T> get _config => widget.config;

  bool get _isDrawer {
    if (_config.presentation == CollectionEditorPresentation.drawer ||
        _config.presentation == CollectionEditorPresentation.bottomFormSheet) {
      return true;
    }
    if (_config.presentation == CollectionEditorPresentation.adaptive) {
      return AppAdaptiveModalShellScope.maybeIsDrawer(context);
    }
    return false;
  }

  AutovalidateMode get _autovalidateMode =>
      _config.autovalidateAfterSubmit && _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _config.initialName);
    _descriptionController = TextEditingController(
      text: _config.initialDescription,
    );
  }

  @override
  void dispose() {
    _dismissController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_config.presentation) {
      case CollectionEditorPresentation.dialog:
        return AppDesktopDialog(
          width:
              _config.dialogWidth ??
              context.appComponentTokens.playlistDialogWidth,
          child: _buildForm(context),
        );
      case CollectionEditorPresentation.bottomFormSheet:
        return AppBottomFormSheet(
          formKey: _formKey,
          title: _config.copy.title,
          submitKey: _config.submitKey,
          submitLabel: _config.copy.submitLabel,
          isSubmitting: _isSubmitting,
          onSubmit: _submit,
          body: _buildFields(context),
        );
      case CollectionEditorPresentation.drawer:
      case CollectionEditorPresentation.adaptive:
        return _buildForm(context);
    }
  }

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    final isDrawer =
        AppAdaptiveModalShellScope.maybeIsDrawer(context) ||
        _config.presentation == CollectionEditorPresentation.drawer;
    final isEditHeader =
        _config.headerStyle == CollectionEditorHeaderStyle.edit;
    return AppModalDismissScope(
      controller: _dismissController,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(height: isEditHeader ? spacing.lg : spacing.md),
            _buildFields(context),
            SizedBox(height: isEditHeader ? spacing.lg : spacing.md),
            AppModalActionRow(
              submitLabel: _config.copy.submitLabel,
              submitKey: _config.submitKey,
              isSubmitting: _isSubmitting,
              showCancel: false,
              equalWidth: isDrawer,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final copy = _config.copy;
    switch (_config.headerStyle) {
      case CollectionEditorHeaderStyle.plain:
        return Text(
          copy.title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        );
      case CollectionEditorHeaderStyle.strong:
        return Text(
          copy.title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        );
      case CollectionEditorHeaderStyle.edit:
        return Text(
          copy.title,
          style: resolveAppTextStyle(
            context,
            size: _isDrawer ? AppTextSize.s16 : AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        );
    }
  }

  Widget _buildFields(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: _config.nameFieldKey,
          controller: _nameController,
          hintText: _config.copy.nameHint,
          enabled: !_isSubmitting,
          autovalidateMode: _autovalidateMode,
          validator: (value) => value == null || value.trim().isEmpty
              ? _config.copy.nameRequiredMessage
              : null,
        ),
        SizedBox(height: spacing.sm),
        AppTextField(
          fieldKey: _config.descriptionFieldKey,
          controller: _descriptionController,
          hintText: _config.copy.descriptionHint,
          enabled: !_isSubmitting,
          autovalidateMode: _autovalidateMode,
          maxLines: _config.descriptionMaxLines,
          minLines: _config.descriptionMinLines,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (_config.unfocusOnSubmit) {
      FocusScope.of(context).unfocus();
    }
    if (_config.autovalidateAfterSubmit && !_hasAttemptedSubmit) {
      setState(() => _hasAttemptedSubmit = true);
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    _dismissController.setLocked(true);
    setState(() => _isSubmitting = true);
    try {
      final result = await _config.onSubmit(
        ref,
        _nameController.text,
        _descriptionController.text,
      );
      if (!mounted) {
        return;
      }
      _config.onSuccess?.call(context, result);
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: _config.errorFallback(l10n),
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
      _dismissController.setLocked(false);
      setState(() => _isSubmitting = false);
    }
  }
}
