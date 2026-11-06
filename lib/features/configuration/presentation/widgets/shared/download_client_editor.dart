import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';

Future<DownloadClientDto?> showDownloadClientEditor(
  BuildContext context, {
  required bool mobile,
  required List<MediaLibraryDto> libraries,
  required List<MediaProviderDto> providers,
  DownloadClientDto? initialClient,
}) {
  final editor = _DownloadClientEditor(
    mobile: mobile,
    libraries: libraries,
    providers: providers,
    initialClient: initialClient,
  );
  if (mobile) {
    return showAppBottomDrawer<DownloadClientDto>(
      context: context,
      drawerKey: const Key('mobile-downloader-editor-drawer'),
      heightFactor: 0.9,
      builder: (_) => editor,
    );
  }
  return showAppDialog<DownloadClientDto>(
    context: context,
    builder: (_) => editor,
  );
}

class _DownloadClientEditor extends ConsumerStatefulWidget {
  const _DownloadClientEditor({
    required this.mobile,
    required this.libraries,
    required this.providers,
    this.initialClient,
  });

  final bool mobile;
  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<_DownloadClientEditor> createState() =>
      _DownloadClientEditorState();
}

class _DownloadClientEditorState extends ConsumerState<_DownloadClientEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late ProviderConfigFormController _providerConfigController;
  int? _selectedLibraryId;
  bool _isSubmitting = false;
  bool _isTesting = false;
  bool _hasAttemptedSubmit = false;
  DownloadClientDiagnosticReportDto? _diagnosticReport;

  bool get _isEditing => widget.initialClient != null;

  AutovalidateMode? get _autovalidateMode => widget.mobile
      ? (_hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled)
      : null;

  MediaProviderDto? _providerForLibrary(int? libraryId) {
    if (libraryId == null) return null;
    MediaLibraryDto? library;
    for (final item in widget.libraries) {
      if (item.id == libraryId) {
        library = item;
        break;
      }
    }
    if (library == null) return null;
    for (final provider in widget.providers) {
      if (provider.providerKey == library.providerKey) return provider;
    }
    return null;
  }

  ProviderConfigFormController _newConfigController(
    int? libraryId,
    Map<String, dynamic> initialConfig,
  ) {
    final fields =
        _providerForLibrary(libraryId)?.downloadConfigFields ??
        const <ProviderConfigFieldDto>[];
    return ProviderConfigFormController(
      fields: fields,
      initialConfig: initialConfig,
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClient;
    _selectedLibraryId =
        initial?.libraryId ??
        (widget.libraries.isEmpty ? null : widget.libraries.first.id);
    _nameController = TextEditingController(text: initial?.name ?? '');
    _providerConfigController = _newConfigController(
      _selectedLibraryId,
      initial?.providerConfig ?? const <String, dynamic>{},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerConfigController.dispose();
    super.dispose();
  }

  void _selectLibrary(int? value) {
    if (value == _selectedLibraryId) return;
    final old = _providerConfigController;
    final next = _newConfigController(value, const <String, dynamic>{});
    setState(() {
      _selectedLibraryId = value;
      _providerConfigController = next;
    });
    old.dispose();
  }

  DownloadClientFormValue _formValue() {
    return DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
  }

  void _markSubmitAttempted() {
    if (widget.mobile) {
      FocusScope.of(context).unfocus();
      if (!_hasAttemptedSubmit) {
        setState(() => _hasAttemptedSubmit = true);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isTesting) return;
    _markSubmitAttempted();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final value = _formValue();
    setState(() => _isSubmitting = true);
    try {
      final client = _isEditing
          ? await ref
                .read(downloadClientsProvider.notifier)
                .updateClient(
                  clientId: widget.initialClient!.id,
                  payload: value.toUpdatePayload(),
                )
          : await ref
                .read(downloadClientsProvider.notifier)
                .create(value.toCreatePayload());
      if (!mounted) return;
      showToast(
        _isEditing ? l10n.downloaderUpdated : l10n.downloaderCreated,
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(client);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing
              ? l10n.downloaderUpdateFailed
              : l10n.downloaderCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _testClient() async {
    if (_isSubmitting || _isTesting) return;
    _markSubmitAttempted();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final value = _formValue();
    final libraryId = value.libraryId;
    if (libraryId == null) return;
    setState(() {
      _isTesting = true;
      _diagnosticReport = null;
    });
    try {
      final report = await ref
          .read(downloadClientsApiProvider)
          .testClient(
            DownloadClientTestPayload(
              libraryId: libraryId,
              providerConfig: value.providerConfig,
              clientId: widget.initialClient?.id,
            ),
          );
      if (!mounted) return;
      setState(() => _diagnosticReport = report);
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.downloaderTestFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildMobile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? l10n.downloaderEditTitle : l10n.downloaderAdd,
      subtitle: l10n.downloaderFormSubtitle,
      submitKey: const Key('mobile-downloader-submit-button'),
      isSubmitting: _isSubmitting,
      submitDisabled: _isTesting,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFields(context),
          SizedBox(height: context.appSpacing.lg),
          AppButton(
            key: const Key('mobile-downloader-test-button'),
            label: l10n.downloaderTestConfig,
            icon: const Icon(Icons.rule_rounded),
            isLoading: _isTesting,
            onPressed: _isSubmitting || _isTesting ? null : _testClient,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppDesktopDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appLayoutTokens.dialogInsetPadding,
        vertical: context.appLayoutTokens.dialogInsetPadding,
      ),
      width: context.appLayoutTokens.dialogWidthMd,
      showCloseButton: !_isSubmitting,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? l10n.downloaderEditTitle : l10n.downloaderAdd,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xl),
              _buildFields(context),
              SizedBox(height: spacing.xl),
              PopScope(
                canPop: !_isSubmitting,
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: _isTesting || _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        label: l10n.commonCancel,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: _isTesting || _isSubmitting ? null : _submit,
                        label: l10n.commonSave,
                        variant: AppButtonVariant.primary,
                        isLoading: _isSubmitting,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: AppButton(
                        key: const Key('download-client-test-button'),
                        onPressed: _isTesting || _isSubmitting
                            ? null
                            : _testClient,
                        label: l10n.downloaderTestConfig,
                        icon: const Icon(Icons.rule_rounded),
                        size: AppButtonSize.small,
                        isLoading: _isTesting,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFields(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DownloadClientFormFields(
          nameController: _nameController,
          libraries: widget.libraries,
          selectedLibraryId: _selectedLibraryId,
          onLibraryChanged: _selectLibrary,
          providerConfigController: _providerConfigController,
          isEditing: _isEditing,
          enabled: !_isSubmitting && !_isTesting,
          autovalidateMode: _autovalidateMode,
        ),
        if (_diagnosticReport != null) ...[
          SizedBox(height: spacing.lg),
          DownloadClientDiagnosticResultView(report: _diagnosticReport!),
        ],
      ],
    );
  }
}
