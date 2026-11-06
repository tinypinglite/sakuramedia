import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/provider_login_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/provider_login_page.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/provider_login_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_provider_login_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

class MediaLibrariesSection extends ConsumerStatefulWidget {
  const MediaLibrariesSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<MediaLibrariesSection> createState() =>
      _MediaLibrariesSectionState();
}

class _MediaLibrariesSectionState extends ConsumerState<MediaLibrariesSection> {
  @override
  void didUpdateWidget(covariant MediaLibrariesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          unawaited(ref.read(mediaProviderCatalogProvider.notifier).reload());
        }
      });
    }
  }

  Future<List<MediaProviderDto>?> _loadCatalog({bool showError = true}) async {
    try {
      return await ref.read(mediaProviderCatalogProvider.future);
    } catch (error) {
      if (showError && mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaLibraryProviderCatalogLoadFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return null;
    }
  }

  Future<void> _refresh() {
    return Future.wait<void>([
      ref.read(mediaLibrariesProvider.notifier).reload(),
      ref.read(mediaProviderCatalogProvider.notifier).reload(),
    ]);
  }

  Future<void> _createLibrary() async {
    final providers = await _loadCatalog();
    if (!mounted || providers == null) {
      return;
    }
    if (providers.isEmpty) {
      showToast(
        AppLocalizations.of(context).mediaLibraryNoProviderInstalled,
        tone: AppToastTone.warning,
      );
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => MediaLibraryDialog(
        title: AppLocalizations.of(context).mediaLibraryAdd,
        providers: providers,
      ),
    );
  }

  Future<void> _editLibrary(MediaLibraryDto library) async {
    final providers =
        await _loadCatalog(showError: false) ?? const <MediaProviderDto>[];
    if (!mounted) {
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => MediaLibraryDialog(
        title: AppLocalizations.of(context).mediaLibraryEditTitle,
        providers: providers,
        initialLibrary: library,
      ),
    );
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.mediaLibraryDeleteTitle,
      message: l10n.mediaLibraryDeleteMessage(library.name),
      onDelete: () =>
          ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: l10n.mediaLibraryDeleted,
      failureFallback: l10n.mediaLibraryDeleteFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(mediaLibrariesProvider);
    final content = libraries.hasError
        ? AppSectionError(
            title: l10n.mediaLibraryLoadFailedTitle,
            message: apiErrorMessage(
              libraries.error!,
              fallback: l10n.mediaLibraryLoadFailedFallback,
              l10n: l10n,
            ),
            onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
          )
        : Builder(
            builder: (context) {
              final isLoading = libraries.value == null;
              // loading 用占位媒体库渲染真实设置组，由 [AppSkeletonizer] 灰化。
              final display = isLoading
                  ? mediaLibraryPlaceholders()
                  : libraries.value!;
              return AppSkeletonizer(
                enabled: isLoading,
                child: _buildLoaded(context, display),
              );
            },
          );
    return AppPageRefreshScope(onRefresh: _refresh, child: content);
  }

  Widget _buildLoaded(BuildContext context, List<MediaLibraryDto> libraries) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(mediaProviderCatalogProvider);
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNoticeCard(
          leadingIcon: Icons.folder_open_outlined,
          title: l10n.mediaLibraryStorageTitle,
          description: l10n.mediaLibraryStorageDescriptionDesktop,
        ),
        SizedBox(height: spacing.lg),
        if (catalog.hasError)
          AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description: l10n.mediaLibraryProviderCatalogUnavailable,
          ),
        if (catalog.hasError) SizedBox(height: spacing.lg),
        if (catalog.hasValue && providers.isEmpty)
          AppNoticeCard(
            leadingIcon: Icons.extension_off_outlined,
            description: l10n.mediaLibraryNoProviderInstalled,
          ),
        if (catalog.hasValue && providers.isEmpty) SizedBox(height: spacing.lg),
        if (libraries.isEmpty)
          AppEmptyState(message: l10n.mediaLibraryEmpty)
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in libraries)
                _buildLibraryCell(
                  context,
                  library,
                  providers,
                  catalogReady: catalog.hasValue,
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-media-library-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: l10n.mediaLibraryAdd,
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createLibrary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLibraryCell(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final l10n = AppLocalizations.of(context);
    final provider = _findProvider(providers, library.providerKey);
    final unavailable = catalogReady && provider == null;
    return AppSettingCell(
      key: Key('media-library-card-${library.id}'),
      icon: Icons.folder_open_outlined,
      title: library.name,
      subtitle:
          provider?.displayName ??
          (catalogReady
              ? l10n.mediaLibraryProviderUnavailable(library.providerKey)
              : library.providerKey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unavailable)
            Text(
              l10n.mediaLibraryUnavailable,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          if (unavailable) SizedBox(width: context.appSpacing.sm),
          Text(
            'ID ${library.id}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppInlineActionButton(
            key: Key('media-library-edit-${library.id}'),
            icon: Icons.edit_outlined,
            onTap: () => _editLibrary(library),
          ),
          SizedBox(width: context.appSpacing.xs),
          AppInlineActionButton(
            key: Key('media-library-delete-${library.id}'),
            icon: Icons.delete_outline,
            onTap: () => _deleteLibrary(library),
          ),
        ],
      ),
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

class MediaLibraryDialog extends ConsumerStatefulWidget {
  const MediaLibraryDialog({
    super.key,
    required this.title,
    required this.providers,
    this.initialLibrary,
  });

  final String title;
  final List<MediaProviderDto> providers;
  final MediaLibraryDto? initialLibrary;

  @override
  ConsumerState<MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends ConsumerState<MediaLibraryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final ProviderLoginApi _providerLoginApi;
  late String? _selectedProviderKey;
  late ProviderConfigFormController _providerConfigController;
  ProviderLoginSessionDto? _loginSession;
  bool _manualLoginMode = false;
  bool _isOpeningLogin = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialLibrary != null;

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
    setState(() {
      _selectedProviderKey = providerKey;
      final provider = _findProvider(widget.providers, providerKey);
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
    if (_isSubmitting ||
        !(_formKey.currentState?.validate() ?? false) ||
        _selectedProviderKey == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
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
    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await ref
            .read(mediaLibrariesProvider.notifier)
            .updateLibrary(
              libraryId: widget.initialLibrary!.id,
              payload: _selectedProvider == null
                  ? UpdateMediaLibraryPayload(name: value.name)
                  : value.toUpdatePayload(),
            );
      } else {
        await ref
            .read(mediaLibrariesProvider.notifier)
            .create(value.toCreatePayload());
      }
      if (!mounted) return;
      _loginSession = null;
      showToast(
        _isEditing ? l10n.mediaLibraryUpdated : l10n.mediaLibraryCreated,
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final provider = _selectedProvider;
    final login = _libraryLogin;
    final managedKeys = _managedLoginKeys;
    final unavailable = _isEditing && provider == null;
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
                widget.title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xl),
              MediaLibraryFormFields(
                nameController: _nameController,
                enabled: !_isSubmitting,
                onNameSubmitted: (_) => _submit(),
              ),
              SizedBox(height: spacing.lg),
              if (!unavailable)
                MediaLibraryProviderSelectField(
                  providers: widget.providers,
                  value: _selectedProviderKey,
                  enabled: !_isEditing && !_isSubmitting,
                  onChanged: _selectProvider,
                )
              else
                MediaLibraryProviderUnavailableNotice(
                  providerKey: widget.initialLibrary!.providerKey,
                ),
              if (provider != null && login != null) ...[
                SizedBox(height: spacing.lg),
                MediaProviderLoginCard(
                  provider: provider,
                  session: _loginSession,
                  manualMode: _manualLoginMode,
                  isBusy: _isSubmitting || _isOpeningLogin,
                  onLogin: _loginProvider,
                  onUseManual: _useManualLogin,
                ),
                if (_manualLoginMode) ...[
                  SizedBox(height: spacing.md),
                  ProviderConfigFormFields(
                    controller: _providerConfigController,
                    enabled: !_isSubmitting,
                    isEditing: _isEditing,
                    onlyKeys: managedKeys,
                  ),
                ],
              ],
              if (provider != null &&
                  provider.libraryConfigFields.isNotEmpty) ...[
                SizedBox(height: spacing.lg),
                ProviderConfigFormFields(
                  controller: _providerConfigController,
                  enabled: !_isSubmitting,
                  isEditing: _isEditing,
                  excludedKeys: login == null ? const <String>{} : managedKeys,
                ),
              ],
              SizedBox(height: spacing.xl),
              PopScope(
                canPop: !_isSubmitting,
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        label: l10n.commonCancel,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: _isSubmitting ? null : _submit,
                        label: l10n.commonSave,
                        variant: AppButtonVariant.primary,
                        isLoading: _isSubmitting,
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
}
