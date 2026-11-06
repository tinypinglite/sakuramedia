import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/provider_login_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/provider_login_page.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/provider_login_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_provider_login_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/form_submit_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_form_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

Future<MediaLibraryDto?> showMediaLibraryEditor(
  BuildContext context, {
  required bool mobile,
  required List<MediaProviderDto> providers,
  MediaLibraryDto? initialLibrary,
}) async {
  final dismissController = AppModalDismissController();
  return showAppAdaptiveModal<MediaLibraryDto>(
    context: context,
    variant: mobile
        ? AppAdaptiveModalVariant.drawer
        : AppAdaptiveModalVariant.dialog,
    drawerKey: const Key('mobile-media-library-editor-drawer'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopInsetPadding: EdgeInsets.symmetric(
      horizontal: context.appLayoutTokens.dialogInsetPadding,
      vertical: context.appLayoutTokens.dialogInsetPadding,
    ),
    mobileHeightFactor: 0.78,
    dismissController: dismissController,
    builder: (_) => _MediaLibraryEditor(
      mobile: mobile,
      providers: providers,
      initialLibrary: initialLibrary,
      dismissController: dismissController,
    ),
  );
}

class _MediaLibraryEditor extends ConsumerStatefulWidget {
  const _MediaLibraryEditor({
    required this.mobile,
    required this.providers,
    this.initialLibrary,
    this.dismissController,
  });

  final bool mobile;
  final List<MediaProviderDto> providers;
  final MediaLibraryDto? initialLibrary;
  final AppModalDismissController? dismissController;

  @override
  ConsumerState<_MediaLibraryEditor> createState() =>
      _MediaLibraryEditorState();
}

class _MediaLibraryEditorState extends ConsumerState<_MediaLibraryEditor>
    with FormSubmitState<_MediaLibraryEditor> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late final ProviderLoginApi _providerLoginApi;
  late String? _selectedProviderKey;
  late ProviderConfigFormController _providerConfigController;
  ProviderLoginSessionDto? _loginSession;
  bool _manualLoginMode = false;
  bool _isOpeningLogin = false;

  bool get _isEditing => widget.initialLibrary != null;

  @override
  bool get usesMobileFormValidation => widget.mobile;

  MediaProviderDto? get _selectedProvider =>
      _findProvider(widget.providers, _selectedProviderKey ?? '');

  ProviderLoginDto? get _libraryLogin => _selectedProvider?.libraryLogin;

  Set<String> get _managedLoginKeys =>
      _libraryLogin?.managedConfigKeys.toSet() ?? const <String>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _nameFocusNode = FocusNode();
    _providerLoginApi = ref.read(providerLoginApiProvider);
    _selectedProviderKey =
        widget.initialLibrary?.providerKey ??
        (widget.providers.isEmpty ? null : widget.providers.first.providerKey);
    _providerConfigController = ProviderConfigFormController(
      fields:
          _selectedProvider?.libraryConfigFields ??
          const <ProviderConfigFieldDto>[],
      initialConfig:
          widget.initialLibrary?.providerConfig ?? const <String, dynamic>{},
    );
  }

  @override
  void dispose() {
    _deleteLoginSessionRemotely(_loginSession?.id);
    _nameController.dispose();
    _nameFocusNode.dispose();
    _providerConfigController.dispose();
    super.dispose();
  }

  void _deleteLoginSessionRemotely(String? sessionId) {
    if (sessionId == null) return;
    unawaited(_providerLoginApi.deleteSession(sessionId).catchError((_) {}));
  }

  void _clearLoginSession() {
    final sessionId = _loginSession?.id;
    _loginSession = null;
    _manualLoginMode = false;
    _deleteLoginSessionRemotely(sessionId);
  }

  void _selectProvider(String? providerKey) {
    if (providerKey == null ||
        providerKey == _selectedProviderKey ||
        _isEditing) {
      return;
    }
    _providerConfigController.dispose();
    _clearLoginSession();
    final provider = _findProvider(widget.providers, providerKey);
    setState(() {
      _selectedProviderKey = providerKey;
      _providerConfigController = ProviderConfigFormController(
        fields:
            provider?.libraryConfigFields ?? const <ProviderConfigFieldDto>[],
      );
    });
  }

  Future<void> _loginProvider() async {
    final provider = _selectedProvider;
    if (provider == null || _isOpeningLogin) return;
    setState(() => _isOpeningLogin = true);
    try {
      final session = await ref.read(providerLoginLauncherProvider)(
        context,
        provider,
      );
      if (!mounted) {
        _deleteLoginSessionRemotely(session?.id);
        return;
      }
      if (session == null) return;
      final previousId = _loginSession?.id;
      setState(() {
        _loginSession = session;
        _manualLoginMode = false;
      });
      _deleteLoginSessionRemotely(previousId);
    } finally {
      if (mounted) {
        setState(() => _isOpeningLogin = false);
      }
    }
  }

  void _useManualLogin() {
    final sessionId = _loginSession?.id;
    setState(() {
      _loginSession = null;
      _manualLoginMode = true;
    });
    _deleteLoginSessionRemotely(sessionId);
  }

  Future<void> _submit() async {
    if (isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    if (!validateForm() || _selectedProviderKey == null) {
      return;
    }
    final login = _libraryLogin;
    final useManualLogin = login != null && _manualLoginMode;
    final authSessionId = login != null && !useManualLogin
        ? _loginSession?.id
        : null;
    final excludeManagedConfigKeys = login != null && !useManualLogin;
    if (login != null &&
        !useManualLogin &&
        authSessionId == null &&
        !_isEditing) {
      showToast(l10n.providerLoginRequired, tone: AppToastTone.warning);
      return;
    }
    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      providerKey: _selectedProviderKey!,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      excludedProviderConfigKeys: excludeManagedConfigKeys
          ? _managedLoginKeys
          : const <String>{},
      authSessionId: authSessionId,
    );
    setSubmitting(true);
    try {
      final library = _isEditing
          ? await ref
                .read(mediaLibrariesProvider.notifier)
                .updateLibrary(
                  libraryId: widget.initialLibrary!.id,
                  payload: _selectedProvider == null
                      ? UpdateMediaLibraryPayload(name: value.name)
                      : value.toUpdatePayload(),
                )
          : await ref
                .read(mediaLibrariesProvider.notifier)
                .create(value.toCreatePayload());
      if (!mounted) return;
      _loginSession = null;
      showToast(
        _isEditing ? l10n.mediaLibraryUpdated : l10n.mediaLibraryCreated,
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(library);
    } catch (error) {
      if (!mounted) return;
      setSubmitting(false);
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing
              ? l10n.mediaLibraryUpdateFailed
              : l10n.mediaLibraryCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildMobile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = _selectedProvider;
    final unavailable = _isEditing && provider == null;
    return AppBottomFormSheet(
      formKey: formKey,
      title: _isEditing ? l10n.mediaLibraryEditTitle : l10n.mediaLibraryAdd,
      subtitle: unavailable
          ? l10n.mediaLibraryEditSubtitleUnavailable
          : l10n.mediaLibraryEditSubtitle,
      submitKey: const Key('mobile-media-library-submit-button'),
      isSubmitting: isSubmitting,
      dismissController: widget.dismissController,
      onSubmit: _submit,
      body: _buildBody(context),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDesktopFormDialog(
      formKey: formKey,
      title: _isEditing ? l10n.mediaLibraryEditTitle : l10n.mediaLibraryAdd,
      body: _buildBody(context),
      isSubmitting: isSubmitting,
      isBusy: isSubmitting,
      dismissController: widget.dismissController,
      onSubmit: _submit,
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = context.appSpacing;
    final provider = _selectedProvider;
    final login = _libraryLogin;
    final managedKeys = _managedLoginKeys;
    final unavailable = _isEditing && provider == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaLibraryFormFields(
          nameController: _nameController,
          nameFocusNode: widget.mobile ? _nameFocusNode : null,
          enabled: !isSubmitting,
          autovalidateMode: autovalidateMode,
          onNameSubmitted: (_) => _submit(),
        ),
        SizedBox(height: spacing.lg),
        if (unavailable)
          MediaLibraryProviderUnavailableNotice(
            providerKey: widget.initialLibrary!.providerKey,
          )
        else
          MediaLibraryProviderSelectField(
            providers: widget.providers,
            value: _selectedProviderKey,
            enabled: !_isEditing && !isSubmitting,
            onChanged: _selectProvider,
          ),
        if (provider != null && login != null) ...[
          SizedBox(height: spacing.lg),
          MediaProviderLoginCard(
            provider: provider,
            session: _loginSession,
            manualMode: _manualLoginMode,
            isBusy: isSubmitting || _isOpeningLogin,
            onLogin: _loginProvider,
            onUseManual: _useManualLogin,
          ),
          if (_manualLoginMode) ...[
            SizedBox(height: spacing.md),
            ProviderConfigFormFields(
              controller: _providerConfigController,
              enabled: !isSubmitting,
              isEditing: _isEditing,
              onlyKeys: managedKeys,
              autovalidateMode: autovalidateMode,
            ),
          ],
        ],
        if (provider != null && provider.libraryConfigFields.isNotEmpty) ...[
          SizedBox(height: spacing.lg),
          ProviderConfigFormFields(
            controller: _providerConfigController,
            enabled: !isSubmitting,
            isEditing: _isEditing,
            excludedKeys: login == null ? const <String>{} : managedKeys,
            autovalidateMode: autovalidateMode,
          ),
        ],
      ],
    );
  }
}

MediaProviderDto? _findProvider(
  List<MediaProviderDto> providers,
  String providerKey,
) {
  for (final provider in providers) {
    if (provider.providerKey == providerKey) return provider;
  }
  return null;
}
