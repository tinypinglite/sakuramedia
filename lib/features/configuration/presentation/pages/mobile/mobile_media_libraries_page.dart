import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/provider_login_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/provider_login_page.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/provider_login_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_provider_login_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileMediaLibrariesPage extends ConsumerStatefulWidget {
  const MobileMediaLibrariesPage({super.key});

  @override
  ConsumerState<MobileMediaLibrariesPage> createState() =>
      _MobileMediaLibrariesPageState();
}

class _MobileMediaLibrariesPageState
    extends ConsumerState<MobileMediaLibrariesPage> {
  Future<List<MediaProviderDto>?> _loadCatalog() async {
    try {
      return await ref.read(mediaProviderCatalogProvider.future);
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaLibraryProviderCatalogLoadFailed,
            l10n: l10n,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _refreshLibraries() async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (mounted && message != null) showToast(message);
  }

  Future<void> _handleCreateLibrary() async {
    final providers = await _loadCatalog();
    if (!mounted || providers == null) return;
    if (providers.isEmpty) {
      showToast(AppLocalizations.of(context).mediaLibraryNoProviderInstalled);
      return;
    }
    await showMobileMediaLibraryEditorDrawer(context, providers: providers);
  }

  Future<void> _handleEditLibrary(MediaLibraryDto library) async {
    final providers = await _loadCatalog() ?? const <MediaProviderDto>[];
    if (!mounted) return;
    await showMobileMediaLibraryEditorDrawer(
      context,
      providers: providers,
      initialLibrary: library,
    );
  }

  Future<void> _handleLibraryActions(MediaLibraryDto library) async {
    final action = await showMobileMediaLibraryActionsDrawer(
      context,
      library: library,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MobileMediaLibraryAction.edit:
        await _handleEditLibrary(library);
      case MobileMediaLibraryAction.delete:
        await _handleDeleteLibrary(library);
    }
  }

  Future<void> _handleDeleteLibrary(MediaLibraryDto library) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.mediaLibraryDeleteTitle,
      message: l10n.mediaLibraryDeleteMessage(library.name),
      dialogKey: const Key('mobile-media-library-delete-drawer'),
      confirmKey: const Key('mobile-media-library-delete-confirm-button'),
      onDelete: () =>
          ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: l10n.mediaLibraryDeleted,
      failureFallback: l10n.mediaLibraryDeleteFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(mediaLibrariesProvider);
    return ColoredBox(
      key: const Key('mobile-settings-media-libraries'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshLibraries,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.only(top: spacing.md, bottom: spacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppNoticeCard(
                          key: const Key('mobile-media-libraries-notice-card'),
                          leadingIcon: Icons.folder_open_outlined,
                          title: l10n.mediaLibraryStorageTitle,
                          description:
                              l10n.mediaLibraryStorageDescriptionMobile,
                        ),
                        SizedBox(height: spacing.md),
                        _buildCatalogNotice(context),
                        _buildContentSection(context, async),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-media-libraries-create-button'),
                label: l10n.mediaLibraryAdd,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _handleCreateLibrary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogNotice(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(mediaProviderCatalogProvider);
    if (catalog.hasError) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: AppNoticeCard(
          leadingIcon: Icons.warning_amber_rounded,
          description: l10n.mediaLibraryProviderCatalogUnavailable,
        ),
      );
    }
    if (catalog.hasValue && catalog.value!.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: AppNoticeCard(
          leadingIcon: Icons.extension_off_outlined,
          description: l10n.mediaLibraryNoProviderInstalled,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildContentSection(
    BuildContext context,
    AsyncValue<List<MediaLibraryDto>> async,
  ) {
    final l10n = AppLocalizations.of(context);
    if (async.isLoading && async.value == null) {
      return _buildLoadingSection(context);
    }
    if (async.hasError) {
      return AppMobileSectionError(
        key: const Key('mobile-media-libraries-error-state'),
        title: l10n.mediaLibraryLoadFailedTitle,
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.mediaLibraryLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
        retryButtonKey: const Key('mobile-media-libraries-retry-button'),
      );
    }
    final libraries = async.value ?? const <MediaLibraryDto>[];
    if (libraries.isEmpty) {
      return MobileConfigEmptyCard(
        key: const Key('mobile-media-libraries-empty-state'),
        message: l10n.mediaLibraryEmpty,
      );
    }
    final catalog = ref.watch(mediaProviderCatalogProvider);
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: libraries
          .expand(
            (library) => <Widget>[
              _buildLibraryCard(
                context,
                library,
                providers,
                catalogReady: catalog.hasValue,
              ),
              if (library != libraries.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Widget _buildLoadingSection(BuildContext context) {
    final libraries = mediaLibraryPlaceholders(count: 3);
    // loading 用占位媒体库渲染真实卡片，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: libraries
            .expand(
              (library) => <Widget>[
                _buildLibraryCard(
                  context,
                  library,
                  const <MediaProviderDto>[],
                  catalogReady: false,
                ),
                if (library != libraries.last)
                  SizedBox(height: context.appSpacing.sm),
              ],
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLibraryCard(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    final provider = _findProvider(providers, library.providerKey);
    final unavailable = catalogReady && provider == null;
    final avatarSide = componentTokens.iconSizeXl + spacing.md;
    return MobileEntityListCard(
      outerKey: Key('mobile-media-library-card-${library.id}'),
      bodyKey: Key('mobile-media-library-card-body-${library.id}'),
      leading: Container(
        width: avatarSide,
        height: avatarSide,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Icon(
          Icons.folder_open_outlined,
          size: componentTokens.iconSizeMd,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        library.name,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      body: [
        SizedBox(height: spacing.xs),
        Text(
          provider?.displayName ??
              (catalogReady
                  ? l10n.mediaLibraryProviderUnavailable(library.providerKey)
                  : library.providerKey),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: unavailable ? AppTextTone.error : AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          'ID: ${library.id}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          l10n.mediaLibraryUpdatedAt(
            formatUpdatedAtLabel(library.updatedAt) ?? l10n.commonUnknown,
          ),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
      onTap: () => _handleEditLibrary(library),
      trailingAction: AppIconButton(
        key: Key('mobile-media-library-more-${library.id}'),
        tooltip: l10n.mediaLibraryMoreActions,
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        onPressed: () => _handleLibraryActions(library),
        icon: const Icon(Icons.more_horiz_rounded),
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

Future<MediaLibraryDto?> showMobileMediaLibraryEditorDrawer(
  BuildContext context, {
  required List<MediaProviderDto> providers,
  MediaLibraryDto? initialLibrary,
}) {
  return showAppBottomDrawer<MediaLibraryDto>(
    context: context,
    drawerKey: const Key('mobile-media-library-editor-drawer'),
    heightFactor: 0.78,
    builder: (_) => _MobileMediaLibraryEditorDrawer(
      providers: providers,
      initialLibrary: initialLibrary,
    ),
  );
}

Future<MobileMediaLibraryAction?> showMobileMediaLibraryActionsDrawer(
  BuildContext context, {
  required MediaLibraryDto library,
}) {
  return showAppBottomDrawer<MobileMediaLibraryAction>(
    context: context,
    drawerKey: const Key('mobile-media-library-actions-drawer'),
    maxHeightFactor: 0.34,
    builder: (_) => _MobileMediaLibraryActionsDrawer(library: library),
  );
}

enum MobileMediaLibraryAction { edit, delete }

class _MobileMediaLibraryEditorDrawer extends ConsumerStatefulWidget {
  const _MobileMediaLibraryEditorDrawer({
    required this.providers,
    this.initialLibrary,
  });

  final List<MediaProviderDto> providers;
  final MediaLibraryDto? initialLibrary;

  @override
  ConsumerState<_MobileMediaLibraryEditorDrawer> createState() =>
      _MobileMediaLibraryEditorDrawerState();
}

class _MobileMediaLibraryEditorDrawerState
    extends ConsumerState<_MobileMediaLibraryEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late final ProviderLoginApi _providerLoginApi;
  late String? _selectedProviderKey;
  late ProviderConfigFormController _providerConfigController;
  ProviderLoginSessionDto? _loginSession;
  bool _manualLoginMode = false;
  bool _isOpeningLogin = false;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialLibrary != null;
  MediaProviderDto? get _selectedProvider =>
      _findProvider(widget.providers, _selectedProviderKey ?? '');
  ProviderLoginDto? get _libraryLogin => _selectedProvider?.libraryLogin;
  Set<String> get _managedLoginKeys =>
      _libraryLogin?.managedConfigKeys.toSet() ?? const <String>{};
  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _providerLoginApi = ref.read(providerLoginApiProvider);
    _nameFocusNode = FocusNode();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = _selectedProvider;
    final login = _libraryLogin;
    final managedKeys = _managedLoginKeys;
    final unavailable = _isEditing && provider == null;
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? l10n.mediaLibraryEditTitle : l10n.mediaLibraryAdd,
      subtitle: unavailable
          ? l10n.mediaLibraryEditSubtitleUnavailable
          : l10n.mediaLibraryEditSubtitle,
      submitKey: const Key('mobile-media-library-submit-button'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaLibraryFormFields(
            nameController: _nameController,
            nameFocusNode: _nameFocusNode,
            enabled: !_isSubmitting,
            autovalidateMode: _autovalidateMode,
            onNameSubmitted: (_) => _submit(),
          ),
          SizedBox(height: context.appSpacing.lg),
          if (unavailable)
            MediaLibraryProviderUnavailableNotice(
              providerKey: widget.initialLibrary!.providerKey,
            )
          else
            MediaLibraryProviderSelectField(
              providers: widget.providers,
              value: _selectedProviderKey,
              enabled: !_isEditing && !_isSubmitting,
              onChanged: _selectProvider,
            ),
          if (provider != null && login != null) ...[
            SizedBox(height: context.appSpacing.lg),
            MediaProviderLoginCard(
              provider: provider,
              session: _loginSession,
              manualMode: _manualLoginMode,
              isBusy: _isSubmitting || _isOpeningLogin,
              onLogin: _loginProvider,
              onUseManual: _useManualLogin,
            ),
            if (_manualLoginMode) ...[
              SizedBox(height: context.appSpacing.md),
              ProviderConfigFormFields(
                controller: _providerConfigController,
                enabled: !_isSubmitting,
                isEditing: _isEditing,
                onlyKeys: managedKeys,
                autovalidateMode: _autovalidateMode,
              ),
            ],
          ],
          if (provider != null && provider.libraryConfigFields.isNotEmpty) ...[
            SizedBox(height: context.appSpacing.lg),
            ProviderConfigFormFields(
              controller: _providerConfigController,
              enabled: !_isSubmitting,
              isEditing: _isEditing,
              excludedKeys: login == null ? const <String>{} : managedKeys,
              autovalidateMode: _autovalidateMode,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() => _hasAttemptedSubmit = true);
    }
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedProviderKey == null) {
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
      showToast(l10n.providerLoginRequired);
      return;
    }
    setState(() => _isSubmitting = true);
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
      );
      Navigator.of(context).pop(library);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing
              ? l10n.mediaLibraryUpdateFailed
              : l10n.mediaLibraryCreateFailed,
          l10n: l10n,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }
}

class _MobileMediaLibraryActionsDrawer extends StatelessWidget {
  const _MobileMediaLibraryActionsDrawer({required this.library});

  final MediaLibraryDto library;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          library.name,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          library.providerKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        _MobileDrawerActionRow(
          key: const Key('mobile-media-library-action-edit'),
          icon: Icons.edit_outlined,
          label: l10n.mediaLibraryEditAction,
          onTap: () => Navigator.of(context).pop(MobileMediaLibraryAction.edit),
        ),
        SizedBox(height: spacing.sm),
        _MobileDrawerActionRow(
          key: const Key('mobile-media-library-action-delete'),
          icon: Icons.delete_outline_rounded,
          label: l10n.mediaLibraryDeleteAction,
          tone: AppTextTone.error,
          onTap: () =>
              Navigator.of(context).pop(MobileMediaLibraryAction.delete),
        ),
      ],
    );
  }
}

class _MobileDrawerActionRow extends StatelessWidget {
  const _MobileDrawerActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = AppTextTone.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppTextTone tone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final textColor = resolveAppTextToneColor(context, tone);
    return Material(
      color: Colors.transparent,
      child: AppInteractiveSurface(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: context.appRadius.lgBorder,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: context.appComponentTokens.iconSizeMd,
                color: textColor,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: tone,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeLg,
                color: context.appTextPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
