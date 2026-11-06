import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_info_pill.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

class DownloadClientsSection extends ConsumerStatefulWidget {
  const DownloadClientsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DownloadClientsSection> createState() =>
      _DownloadClientsSectionState();
}

class _DownloadClientsSectionState
    extends ConsumerState<DownloadClientsSection> {
  Future<void> _createClient(
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => DownloadClientDialog(
        libraries: libraries,
        providers: providers,
        title: AppLocalizations.of(context).downloaderAddTitle,
      ),
    );
  }

  Future<void> _editClient(
    DownloadClientDto client,
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => DownloadClientDialog(
        libraries: libraries,
        providers: providers,
        title: AppLocalizations.of(context).downloaderEditTitle,
        initialClient: client,
      ),
    );
  }

  Future<void> _deleteClient(DownloadClientDto client) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.downloaderDeleteTitle,
      message: l10n.downloaderDeleteMessage(client.name),
      onDelete: () =>
          ref.read(downloadClientsProvider.notifier).delete(client.id),
      successToast: l10n.downloaderDeleted,
      failureFallback: l10n.downloaderDeleteFailed,
    );
  }

  List<MediaLibraryDto> _librariesForEdit(
    DownloadClientDto client,
    List<MediaLibraryDto> downloadableLibraries,
    Map<int, MediaLibraryDto> librariesById,
  ) {
    if (downloadableLibraries.any(
      (library) => library.id == client.libraryId,
    )) {
      return downloadableLibraries;
    }
    final currentLibrary = librariesById[client.libraryId];
    if (currentLibrary == null) return downloadableLibraries;
    return <MediaLibraryDto>[currentLibrary, ...downloadableLibraries];
  }

  Future<void> _refresh() {
    return Future.wait<void>([
      ref.read(downloadClientsProvider.notifier).reload(),
      ref.read(mediaLibrariesProvider.notifier).reload(),
      ref.read(mediaProviderCatalogProvider.notifier).reload(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final providersAsync = ref.watch(mediaProviderCatalogProvider);
    // 首屏语义：只有某个列表尚无数据可显示时才铺骨架，避免刷新盖掉已有配置。
    final isLoading =
        (clientsAsync.isLoading && clientsAsync.value == null) ||
        (librariesAsync.isLoading && librariesAsync.value == null) ||
        (providersAsync.isLoading && providersAsync.value == null);
    if (!isLoading) {
      final error = clientsAsync.error ?? librariesAsync.error;
      if (error != null) {
        return AppSectionError(
          title: l10n.downloaderConfigLoadFailed,
          message: apiErrorMessage(
            error,
            fallback: l10n.downloaderConfigLoadFailedFallback,
            l10n: l10n,
          ),
          onRetry: () async {
            await Future.wait<void>([
              ref.read(downloadClientsProvider.notifier).reload(),
              ref.read(mediaLibrariesProvider.notifier).reload(),
              ref.read(mediaProviderCatalogProvider.notifier).reload(),
            ]);
          },
        );
      }
    }
    final providerCatalogError = providersAsync.error;

    // loading 用占位数据渲染真实设置组，由 [AppSkeletonizer] 灰化。
    final clients = clientsAsync.value ?? downloadClientPlaceholders();
    final allLibraries = librariesAsync.value ?? mediaLibraryPlaceholders();
    final providers = providersAsync.value ?? mediaProviderPlaceholders();
    final providersByKey = <String, MediaProviderDto>{
      for (final provider in providers) provider.providerKey: provider,
    };
    final downloadableLibraries = allLibraries
        .where(
          (library) =>
              providersByKey[library.providerKey]?.supportsDownloads ?? false,
        )
        .toList(growable: false);
    final librariesById = <int, MediaLibraryDto>{
      for (final library in allLibraries) library.id: library,
    };
    final spacing = context.appSpacing;

    return AppSkeletonizer(
      enabled: isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (providerCatalogError != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.lg),
              child: Text(
                l10n.downloaderProviderUnavailable,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            )
          else if (downloadableLibraries.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.lg),
              child: Text(
                l10n.downloaderNoDownloadableLibraryProvider,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ).copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (clients.isEmpty)
            AppEmptyState(message: l10n.downloaderEmpty)
          else
            AppSettingsGroup(
              children: [
                for (final client in clients)
                  DownloadClientCard(
                    client: client,
                    mediaLibrary: librariesById[client.libraryId],
                    provider:
                        providersByKey[librariesById[client.libraryId]
                            ?.providerKey],
                    onEdit: () => _editClient(
                      client,
                      _librariesForEdit(
                        client,
                        downloadableLibraries,
                        librariesById,
                      ),
                      providers,
                    ),
                    onDelete: () => _deleteClient(client),
                  ),
              ],
            ),
          SizedBox(height: spacing.lg),
          AppSettingsGroup(
            children: [
              AppSettingCell(
                key: const Key('configuration-download-client-create-button'),
                icon: Icons.add_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: l10n.downloaderCreate,
                titleTone: AppTextTone.accent,
                titleWeight: AppTextWeight.medium,
                trailing: const AppSettingCellChevron(),
                onTap: downloadableLibraries.isEmpty
                    ? null
                    : () => _createClient(downloadableLibraries, providers),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DownloadClientCard extends StatelessWidget {
  const DownloadClientCard({
    super.key,
    required this.client,
    required this.mediaLibrary,
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final MediaProviderDto? provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final providerName =
        provider?.displayName ??
        mediaLibrary?.providerKey ??
        l10n.downloaderUnknownProvider;
    final libraryName =
        mediaLibrary?.name ?? l10n.downloaderUnmatchedLibrary(client.libraryId);
    return Padding(
      key: Key('download-client-card-${client.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSettingIconBox(icon: Icons.cloud_download_outlined),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '$providerName · $libraryName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              AppInlineActionButton(
                key: Key('download-client-edit-${client.id}'),
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              SizedBox(width: spacing.xs),
              AppInlineActionButton(
                key: Key('download-client-delete-${client.id}'),
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Padding(
            padding: EdgeInsets.only(left: spacing.xxl + spacing.md),
            child: Wrap(
              spacing: spacing.md,
              runSpacing: spacing.sm,
              children: [
                AppInfoPill(label: 'Provider', value: providerName),
                AppInfoPill(
                  label: l10n.downloaderMediaLibraryLabel,
                  value: libraryName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadClientDialog extends ConsumerStatefulWidget {
  const DownloadClientDialog({
    super.key,
    required this.libraries,
    required this.providers,
    required this.title,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  final String title;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<DownloadClientDialog> createState() =>
      _DownloadClientDialogState();
}

class _DownloadClientDialogState extends ConsumerState<DownloadClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late ProviderConfigFormController _providerConfigController;
  int? _selectedLibraryId;
  bool _isTesting = false;
  bool _isSubmitting = false;
  DownloadClientDiagnosticReportDto? _diagnosticReport;

  bool get _isEditing => widget.initialClient != null;

  MediaProviderDto? _providerForLibrary(int? libraryId) {
    if (libraryId == null) return null;
    final library = widget.libraries.cast<MediaLibraryDto?>().firstWhere(
      (item) => item?.id == libraryId,
      orElse: () => null,
    );
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

  Future<void> _submit() async {
    if (_isSubmitting || _isTesting) return;
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await ref
            .read(downloadClientsProvider.notifier)
            .updateClient(
              clientId: widget.initialClient!.id,
              payload: value.toUpdatePayload(),
            );
      } else {
        await ref
            .read(downloadClientsProvider.notifier)
            .create(value.toCreatePayload());
      }
      if (!mounted) return;
      showToast(
        _isEditing ? l10n.downloaderUpdated : l10n.downloaderCreated,
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
              ? l10n.downloaderUpdateFailed
              : l10n.downloaderCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _testClient() async {
    if (_isTesting || _isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
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
                widget.title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xl),
              DownloadClientFormFields(
                nameController: _nameController,
                libraries: widget.libraries,
                selectedLibraryId: _selectedLibraryId,
                onLibraryChanged: _selectLibrary,
                providerConfigController: _providerConfigController,
                isEditing: _isEditing,
                enabled: !_isTesting && !_isSubmitting,
              ),
              if (_diagnosticReport != null) ...[
                SizedBox(height: spacing.lg),
                DownloadClientDiagnosticResultView(report: _diagnosticReport!),
              ],
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
}
