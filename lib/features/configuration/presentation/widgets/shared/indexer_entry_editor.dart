import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_settings_actions.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/form_submit_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_form_dialog.dart';

Future<IndexerEntryDto?> showIndexerEntryEditor(
  BuildContext context, {
  required bool mobile,
  required List<IndexerEntryDto> existingEntries,
  required List<DownloadClientDto> downloadClients,
  IndexerEntryDto? initialEntry,
}) {
  return showAppAdaptiveModal<IndexerEntryDto>(
    context: context,
    variant: mobile
        ? AppAdaptiveModalVariant.drawer
        : AppAdaptiveModalVariant.dialog,
    drawerKey: const Key('mobile-indexer-editor-drawer'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopInsetPadding: EdgeInsets.symmetric(
      horizontal: context.appLayoutTokens.dialogInsetPadding,
      vertical: context.appLayoutTokens.dialogInsetPadding,
    ),
    mobileHeightFactor: 0.8,
    builder: (_) => _IndexerEntryEditor(
      mobile: mobile,
      existingEntries: existingEntries,
      downloadClients: downloadClients,
      initialEntry: initialEntry,
    ),
  );
}

class _IndexerEntryEditor extends ConsumerStatefulWidget {
  const _IndexerEntryEditor({
    required this.mobile,
    required this.existingEntries,
    required this.downloadClients,
    this.initialEntry,
  });

  final bool mobile;
  final List<IndexerEntryDto> existingEntries;
  final List<DownloadClientDto> downloadClients;
  final IndexerEntryDto? initialEntry;

  @override
  ConsumerState<_IndexerEntryEditor> createState() =>
      _IndexerEntryEditorState();
}

class _IndexerEntryEditorState extends ConsumerState<_IndexerEntryEditor>
    with FormSubmitState<_IndexerEntryEditor> {
  late final IndexerEntryFormController _controller;
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;

  bool get _isEditing => widget.initialEntry != null;

  @override
  bool get usesMobileFormValidation => widget.mobile;

  @override
  void initState() {
    super.initState();
    _controller = IndexerEntryFormController(initialEntry: widget.initialEntry);
    _nameFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  IndexerEntryDto _buildEntry() {
    return _controller.toDto(widget.downloadClients);
  }

  void _submitDesktop() {
    if (!validateForm()) return;
    final entry = _buildEntry();
    if (entry.downloadClients.isEmpty) {
      showToast(
        AppLocalizations.of(context).indexerSelectDownloader,
        tone: AppToastTone.warning,
      );
      return;
    }
    Navigator.of(context).pop(entry);
  }

  Future<void> _submitMobile() async {
    if (isSubmitting) return;
    if (!validateForm()) return;
    final l10n = AppLocalizations.of(context);
    final entry = _buildEntry();
    if (entry.downloadClients.isEmpty) {
      showToast(l10n.indexerSelectDownloader, tone: AppToastTone.warning);
      return;
    }
    final nextEntries = List<IndexerEntryDto>.of(widget.existingEntries);
    final existingIndex = nextEntries.indexWhere(
      (item) => item.id == widget.initialEntry?.id,
    );
    if (existingIndex >= 0) {
      nextEntries[existingIndex] = entry;
    } else {
      nextEntries.add(entry);
    }
    setSubmitting(true);
    final saved = await saveIndexerDraft(
      ref: ref,
      context: context,
      indexers: nextEntries,
      successToast: _isEditing ? l10n.indexerUpdated : l10n.indexerCreated,
      failureFallback: _isEditing
          ? l10n.indexerUpdateFailed
          : l10n.indexerCreateFailed,
    );
    if (!mounted) return;
    if (!saved) {
      setSubmitting(false);
      return;
    }
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildMobile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBottomFormSheet(
      formKey: formKey,
      title: _isEditing ? l10n.indexerEditTitle : l10n.indexerAdd,
      subtitle: l10n.indexerFormSubtitle,
      submitKey: const Key('mobile-indexer-submit-button'),
      isSubmitting: isSubmitting,
      onSubmit: _submitMobile,
      body: _buildFields(context),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDesktopFormDialog(
      formKey: formKey,
      title: _isEditing ? l10n.indexerEditTitle : l10n.indexerAdd,
      body: _buildFields(context),
      submitKey: const Key('indexer-entry-submit-button'),
      onSubmit: widget.downloadClients.isEmpty ? null : _submitDesktop,
    );
  }

  Widget _buildFields(BuildContext context) {
    return IndexerEntryFormFields(
      nameController: _controller.nameController,
      urlController: _controller.urlController,
      apiKeyController: _controller.apiKeyController,
      kind: _controller.kind,
      downloadClients: widget.downloadClients,
      selectedDownloadClientIds: _controller.selectedDownloadClientIds,
      existingEntries: widget.existingEntries,
      editingEntryId: widget.initialEntry?.id,
      enabled: !isSubmitting,
      autovalidateMode: autovalidateMode,
      nameFocusNode: widget.mobile ? _nameFocusNode : null,
      urlFocusNode: widget.mobile ? _urlFocusNode : null,
      onKindChanged: (value) => setState(() => _controller.kind = value),
      onDownloadClientsChanged: (value) =>
          setState(() => _controller.selectedDownloadClientIds = value),
      onSubmitted: widget.mobile ? () => _submitMobile() : _submitDesktop,
    );
  }
}
