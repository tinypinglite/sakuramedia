import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileDownloadersPage extends ConsumerStatefulWidget {
  const MobileDownloadersPage({super.key});

  @override
  ConsumerState<MobileDownloadersPage> createState() =>
      _MobileDownloadersPageState();
}

class _MobileDownloadersPageState extends ConsumerState<MobileDownloadersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await Future.wait<void>([
        ref.read(downloadClientsProvider.notifier).reload(),
        ref.read(mediaLibrariesProvider.notifier).reload(),
        ref.read(mediaProviderCatalogProvider.notifier).reload(),
      ]);
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.downloaderLoadFailedFallback,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _createClient(
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showMobileDownloaderEditorDrawer(
      context,
      libraries: libraries,
      providers: providers,
    );
  }

  Future<void> _editClient(
    DownloadClientDto client,
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showMobileDownloaderEditorDrawer(
      context,
      libraries: libraries,
      providers: providers,
      initialClient: client,
    );
  }

  Future<void> _deleteClient(DownloadClientDto client) {
    final l10n = AppLocalizations.of(context);
    return showAppConfigDeleteConfirm(
      context: context,
      title: l10n.downloaderDeleteTitle,
      message: l10n.downloaderDeleteMessage(client.name),
      dialogKey: const Key('mobile-downloader-delete-drawer'),
      confirmKey: const Key('mobile-downloader-delete-confirm-button'),
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final providersAsync = ref.watch(mediaProviderCatalogProvider);

    final clients = clientsAsync.value ?? const <DownloadClientDto>[];
    final allLibraries = librariesAsync.value ?? const <MediaLibraryDto>[];
    final providers = providersAsync.value ?? const <MediaProviderDto>[];
    final providersByKey = <String, MediaProviderDto>{
      for (final provider in providers) provider.providerKey: provider,
    };
    final downloadableLibraries = allLibraries
        .where(
          (library) =>
              providersByKey[library.providerKey]?.supportsDownloads ?? false,
        )
        .toList(growable: false);

    // 首屏语义：只有某个列表尚无数据可显示时才铺骨架，避免刷新盖掉已有配置。
    final loading =
        (clientsAsync.isLoading && clientsAsync.value == null) ||
        (librariesAsync.isLoading && librariesAsync.value == null) ||
        (providersAsync.isLoading && providersAsync.value == null);
    final error = clientsAsync.error ?? librariesAsync.error;

    return ColoredBox(
      key: const Key('mobile-settings-downloaders'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppTabBar(
                controller: _tabController,
                variant: AppTabBarVariant.compact,
                tabs: [
                  Tab(
                    key: const Key('mobile-downloaders-tab-downloaders'),
                    text: l10n.downloaderTabDownloaders,
                  ),
                  Tab(
                    key: const Key('mobile-downloaders-tab-guide'),
                    text: l10n.downloaderTabGuide,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AppKeepAlive(
                  child: _buildDownloadersTab(
                    context,
                    clients: clients,
                    libraries: allLibraries,
                    downloadableLibraries: downloadableLibraries,
                    providers: providers,
                    loading: loading,
                    error: error,
                    providerCatalogUnavailable: providersAsync.hasError,
                  ),
                ),
                AppKeepAlive(
                  child: _buildGuideTab(
                    context,
                    clients: clients,
                    libraries: downloadableLibraries,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-downloaders-create-button'),
                label: l10n.downloaderAdd,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed:
                    loading || error != null || downloadableLibraries.isEmpty
                    ? null
                    : () => _createClient(downloadableLibraries, providers),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadersTab(
    BuildContext context, {
    required List<DownloadClientDto> clients,
    required List<MediaLibraryDto> libraries,
    required List<MediaLibraryDto> downloadableLibraries,
    required List<MediaProviderDto> providers,
    required bool loading,
    required Object? error,
    required bool providerCatalogUnavailable,
  }) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final providersByKey = <String, MediaProviderDto>{
      for (final provider in providers) provider.providerKey: provider,
    };
    final librariesById = <int, MediaLibraryDto>{
      for (final library in libraries) library.id: library,
    };
    return AppAdaptiveRefreshScrollView(
      onRefresh: _refresh,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppNoticeCard(
                  key: const Key('mobile-downloaders-overview-card'),
                  title: l10n.downloaderOverviewTitle,
                  description: l10n.downloaderOverviewDescription,
                  stats: [
                    AppNoticeStat(
                      label: l10n.downloaderConfiguredCount,
                      value: '${clients.length}',
                      valueSize: AppTextSize.s18,
                    ),
                    AppNoticeStat(
                      label: l10n.downloaderAvailableLibraries,
                      value: '${downloadableLibraries.length}',
                      valueSize: AppTextSize.s18,
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                if (providerCatalogUnavailable) ...[
                  AppNoticeCard(
                    key: const Key('mobile-downloaders-provider-catalog-error'),
                    leadingIcon: Icons.warning_amber_rounded,
                    description: l10n.downloaderProviderUnavailable,
                  ),
                  SizedBox(height: spacing.md),
                ],
                if (loading)
                  _MobileDownloadersLoadingSection()
                else if (error != null)
                  AppMobileSectionError(
                    key: const Key('mobile-downloaders-error-state'),
                    title: l10n.downloaderLoadFailedTitle,
                    message: apiErrorMessage(
                      error,
                      fallback: l10n.downloaderLoadFailedFallback,
                      l10n: l10n,
                    ),
                    onRetry: _refresh,
                    retryButtonKey: const Key(
                      'mobile-downloaders-retry-button',
                    ),
                  )
                else if (clients.isEmpty)
                  MobileConfigEmptyCard(
                    key: const Key('mobile-downloaders-empty-state'),
                    message: l10n.downloaderEmpty,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < clients.length; index++) ...[
                        if (index > 0) SizedBox(height: spacing.sm),
                        _MobileDownloaderCard(
                          client: clients[index],
                          mediaLibrary: librariesById[clients[index].libraryId],
                          provider:
                              providersByKey[librariesById[clients[index]
                                      .libraryId]
                                  ?.providerKey],
                          onEdit: () => _editClient(
                            clients[index],
                            _librariesForEdit(
                              clients[index],
                              downloadableLibraries,
                              librariesById,
                            ),
                            providers,
                          ),
                          onDelete: () => _deleteClient(clients[index]),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideTab(
    BuildContext context, {
    required List<DownloadClientDto> clients,
    required List<MediaLibraryDto> libraries,
  }) {
    final l10n = AppLocalizations.of(context);
    final readyLibraries = libraries.isNotEmpty;
    return AppAdaptiveRefreshScrollView(
      onRefresh: _refresh,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(context.appSpacing.md),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-libraries'),
                  title: l10n.downloaderGuideLibrariesTitle,
                  description: l10n.downloaderGuideLibrariesDescription,
                  tip: l10n.downloaderGuideLibrariesTip,
                  badgeLabel: readyLibraries
                      ? l10n.downloaderGuideConfigured
                      : l10n.downloaderGuidePending,
                  badgeTone: readyLibraries
                      ? AppBadgeTone.success
                      : AppBadgeTone.warning,
                  actionLabel: l10n.downloaderGuideGoToLibraries,
                  onActionTap: () => GoRouter.of(
                    context,
                  ).push(mobileSettingsMediaLibrariesPath),
                ),
                SizedBox(height: context.appSpacing.md),
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-downloaders'),
                  title: l10n.downloaderGuideConfigureTitle,
                  description: l10n.downloaderGuideConfigureDescription,
                  tip: l10n.downloaderGuideSensitiveHint,
                  badgeLabel: clients.isNotEmpty
                      ? l10n.downloaderGuideConfigured
                      : l10n.downloaderGuidePending,
                  badgeTone: clients.isNotEmpty
                      ? AppBadgeTone.success
                      : AppBadgeTone.warning,
                  actionLabel: l10n.downloaderGuideSwitchToDownloaders,
                  onActionTap: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileDownloaderCard extends StatelessWidget {
  const _MobileDownloaderCard({
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
    return MobileEntityListCard(
      outerKey: Key('mobile-downloader-card-${client.id}'),
      bodyKey: Key('mobile-downloader-card-body-${client.id}'),
      leading: Container(
        width: context.appComponentTokens.iconSizeXl + spacing.md,
        height: context.appComponentTokens.iconSizeXl + spacing.md,
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: const Icon(Icons.cloud_download_outlined),
      ),
      title: Text(
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
      body: [
        SizedBox(height: spacing.xs),
        _DownloaderMetaLine(label: 'Provider', value: providerName),
        _DownloaderMetaLine(
          label: l10n.downloaderMediaLibraryLabel,
          value: libraryName,
        ),
      ],
      onTap: onEdit,
      trailingAction: IconButton(
        key: Key('mobile-downloader-delete-${client.id}'),
        tooltip: l10n.commonDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

class _DownloaderMetaLine extends StatelessWidget {
  const _DownloaderMetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

Future<DownloadClientDto?> showMobileDownloaderEditorDrawer(
  BuildContext context, {
  required List<MediaLibraryDto> libraries,
  required List<MediaProviderDto> providers,
  DownloadClientDto? initialClient,
}) {
  return showAppBottomDrawer<DownloadClientDto>(
    context: context,
    drawerKey: const Key('mobile-downloader-editor-drawer'),
    heightFactor: 0.9,
    builder: (_) => _MobileDownloaderEditorDrawer(
      libraries: libraries,
      providers: providers,
      initialClient: initialClient,
    ),
  );
}

class _MobileDownloaderEditorDrawer extends ConsumerStatefulWidget {
  const _MobileDownloaderEditorDrawer({
    required this.libraries,
    required this.providers,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<_MobileDownloaderEditorDrawer> createState() =>
      _MobileDownloaderEditorDrawerState();
}

class _MobileDownloaderEditorDrawerState
    extends ConsumerState<_MobileDownloaderEditorDrawer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late ProviderConfigFormController _providerConfigController;
  int? _selectedLibraryId;
  bool _isSubmitting = false;
  bool _isTesting = false;
  bool _hasAttemptedSubmit = false;
  DownloadClientDiagnosticReportDto? _diagnosticReport;

  bool get _isEditing => widget.initialClient != null;

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

  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  Future<void> _submit() async {
    if (_isSubmitting || _isTesting) return;
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _hasAttemptedSubmit = true);
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
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _hasAttemptedSubmit = true);
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
            SizedBox(height: context.appSpacing.lg),
            DownloadClientDiagnosticResultView(report: _diagnosticReport!),
          ],
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
}

class _MobileDownloadersLoadingSection extends StatelessWidget {
  const _MobileDownloadersLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final placeholders = downloadClientPlaceholders(count: 3);
    // loading 用占位下载器渲染真实卡片，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < placeholders.length; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            _MobileDownloaderCard(
              client: placeholders[index],
              mediaLibrary: null,
              provider: null,
              onEdit: () {},
              onDelete: () {},
            ),
          ],
        ],
      ),
    );
  }
}
