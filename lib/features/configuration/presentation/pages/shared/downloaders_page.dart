import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_info_pill.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 下载器设置页：桌面分类页与移动子页共用数据、动作和编辑器。
class DownloadersPage extends ConsumerStatefulWidget {
  const DownloadersPage({super.key, required this.mobile, this.active = true});

  final bool mobile;
  final bool active;

  @override
  ConsumerState<DownloadersPage> createState() => _DownloadersPageState();
}

class _DownloadersPageState extends ConsumerState<DownloadersPage>
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
      if (!mounted) return;
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

  Future<void> _createClient(_DownloadersData data) {
    return showDownloadClientEditor(
      context,
      mobile: widget.mobile,
      libraries: data.downloadableLibraries,
      providers: data.providers,
    );
  }

  Future<void> _editClient(DownloadClientDto client, _DownloadersData data) {
    return showDownloadClientEditor(
      context,
      mobile: widget.mobile,
      libraries: data.librariesForEdit(client),
      providers: data.providers,
      initialClient: client,
    );
  }

  Future<void> _deleteClient(DownloadClientDto client) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.downloaderDeleteTitle,
      message: l10n.downloaderDeleteMessage(client.name),
      dialogKey: widget.mobile
          ? const Key('mobile-downloader-delete-drawer')
          : null,
      confirmKey: widget.mobile
          ? const Key('mobile-downloader-delete-confirm-button')
          : null,
      onDelete: () =>
          ref.read(downloadClientsProvider.notifier).delete(client.id),
      successToast: l10n.downloaderDeleted,
      failureFallback: l10n.downloaderDeleteFailed,
    );
  }

  _DownloadersData _readData({bool withPlaceholders = false}) {
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final providersAsync = ref.watch(mediaProviderCatalogProvider);
    final clients =
        clientsAsync.value ??
        (withPlaceholders
            ? downloadClientPlaceholders()
            : const <DownloadClientDto>[]);
    final libraries =
        librariesAsync.value ??
        (withPlaceholders
            ? mediaLibraryPlaceholders()
            : const <MediaLibraryDto>[]);
    final providers =
        providersAsync.value ??
        (withPlaceholders
            ? mediaProviderPlaceholders()
            : const <MediaProviderDto>[]);
    return _DownloadersData(
      clients: clients,
      libraries: libraries,
      providers: providers,
      loading:
          (clientsAsync.isLoading && clientsAsync.value == null) ||
          (librariesAsync.isLoading && librariesAsync.value == null) ||
          (providersAsync.isLoading && providersAsync.value == null),
      error: clientsAsync.error ?? librariesAsync.error,
      providerCatalogUnavailable: providersAsync.hasError,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final data = _readData(withPlaceholders: true);
    final l10n = AppLocalizations.of(context);
    if (!data.loading && data.error != null) {
      return AppPageRefreshScope(
        onRefresh: _refresh,
        child: AppSectionError(
          key: const Key('downloaders-error-state'),
          title: l10n.downloaderConfigLoadFailed,
          message: apiErrorMessage(
            data.error!,
            fallback: l10n.downloaderConfigLoadFailedFallback,
            l10n: l10n,
          ),
          onRetry: _refresh,
        ),
      );
    }
    final spacing = context.appSpacing;
    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: AppSkeletonizer(
        enabled: data.loading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.providerCatalogUnavailable)
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
            else if (data.downloadableLibraries.isEmpty)
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
            if (data.clients.isEmpty)
              AppEmptyState(
                key: const Key('downloaders-empty-state'),
                message: l10n.downloaderEmpty,
              )
            else
              AppSettingsGroup(
                children: [
                  for (final client in data.clients)
                    _DesktopDownloaderCard(
                      client: client,
                      labels: data.labels(client, l10n),
                      onEdit: () => _editClient(client, data),
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
                  onTap: data.downloadableLibraries.isEmpty
                      ? null
                      : () => _createClient(data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final data = _readData();
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
                AppKeepAlive(child: _buildMobileDownloadersTab(context, data)),
                AppKeepAlive(child: _buildMobileGuideTab(context, data)),
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
                    data.loading ||
                        data.error != null ||
                        data.downloadableLibraries.isEmpty
                    ? null
                    : () => _createClient(data),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDownloadersTab(
    BuildContext context,
    _DownloadersData data,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
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
                      value: '${data.clients.length}',
                      valueSize: AppTextSize.s18,
                    ),
                    AppNoticeStat(
                      label: l10n.downloaderAvailableLibraries,
                      value: '${data.downloadableLibraries.length}',
                      valueSize: AppTextSize.s18,
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                if (data.providerCatalogUnavailable) ...[
                  AppNoticeCard(
                    key: const Key('mobile-downloaders-provider-catalog-error'),
                    leadingIcon: Icons.warning_amber_rounded,
                    description: l10n.downloaderProviderUnavailable,
                  ),
                  SizedBox(height: spacing.md),
                ],
                if (data.loading)
                  _MobileDownloadersLoading()
                else if (data.error != null)
                  AppMobileSectionError(
                    key: const Key('mobile-downloaders-error-state'),
                    title: l10n.downloaderLoadFailedTitle,
                    message: apiErrorMessage(
                      data.error!,
                      fallback: l10n.downloaderLoadFailedFallback,
                      l10n: l10n,
                    ),
                    onRetry: _refresh,
                    retryButtonKey: const Key(
                      'mobile-downloaders-retry-button',
                    ),
                  )
                else if (data.clients.isEmpty)
                  MobileConfigEmptyCard(
                    key: const Key('mobile-downloaders-empty-state'),
                    message: l10n.downloaderEmpty,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = 0;
                        index < data.clients.length;
                        index++
                      ) ...[
                        if (index > 0) SizedBox(height: spacing.sm),
                        _MobileDownloaderCard(
                          client: data.clients[index],
                          labels: data.labels(data.clients[index], l10n),
                          onEdit: () => _editClient(data.clients[index], data),
                          onDelete: () => _deleteClient(data.clients[index]),
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

  Widget _buildMobileGuideTab(BuildContext context, _DownloadersData data) {
    final l10n = AppLocalizations.of(context);
    final readyLibraries = data.downloadableLibraries.isNotEmpty;
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
                  badgeLabel: data.clients.isNotEmpty
                      ? l10n.downloaderGuideConfigured
                      : l10n.downloaderGuidePending,
                  badgeTone: data.clients.isNotEmpty
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

class _DownloadersData {
  _DownloadersData({
    required this.clients,
    required this.libraries,
    required this.providers,
    required this.loading,
    required this.error,
    required this.providerCatalogUnavailable,
  }) {
    providersByKey = {
      for (final provider in providers) provider.providerKey: provider,
    };
    librariesById = {for (final library in libraries) library.id: library};
    downloadableLibraries = libraries
        .where(
          (library) =>
              providersByKey[library.providerKey]?.supportsDownloads ?? false,
        )
        .toList(growable: false);
  }

  final List<DownloadClientDto> clients;
  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  late final Map<String, MediaProviderDto> providersByKey;
  late final Map<int, MediaLibraryDto> librariesById;
  late final List<MediaLibraryDto> downloadableLibraries;
  final bool loading;
  final Object? error;
  final bool providerCatalogUnavailable;

  _DownloaderLabels labels(DownloadClientDto client, AppLocalizations l10n) {
    final library = librariesById[client.libraryId];
    final provider = providersByKey[library?.providerKey];
    return _DownloaderLabels(
      providerName:
          provider?.displayName ??
          library?.providerKey ??
          l10n.downloaderUnknownProvider,
      libraryName:
          library?.name ?? l10n.downloaderUnmatchedLibrary(client.libraryId),
    );
  }

  List<MediaLibraryDto> librariesForEdit(DownloadClientDto client) {
    if (downloadableLibraries.any(
      (library) => library.id == client.libraryId,
    )) {
      return downloadableLibraries;
    }
    final currentLibrary = librariesById[client.libraryId];
    if (currentLibrary == null) return downloadableLibraries;
    return <MediaLibraryDto>[currentLibrary, ...downloadableLibraries];
  }
}

class _DownloaderLabels {
  const _DownloaderLabels({
    required this.providerName,
    required this.libraryName,
  });

  final String providerName;
  final String libraryName;
}

class _DesktopDownloaderCard extends StatelessWidget {
  const _DesktopDownloaderCard({
    required this.client,
    required this.labels,
    required this.onEdit,
    required this.onDelete,
  });

  final DownloadClientDto client;
  final _DownloaderLabels labels;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final providerName = labels.providerName;
    final libraryName = labels.libraryName;
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
              AppIconButton(
                key: Key('download-client-edit-${client.id}'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.commonEdit,
                size: AppIconButtonSize.inline,
                iconColor: context.appTextPalette.secondary,
                onPressed: onEdit,
              ),
              SizedBox(width: spacing.xs),
              AppIconButton(
                key: Key('download-client-delete-${client.id}'),
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.commonDelete,
                size: AppIconButtonSize.inline,
                iconColor: context.appTextPalette.secondary,
                onPressed: onDelete,
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
                AppInfoTile(label: l10n.commonProvider, value: providerName),
                AppInfoTile(
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

class _MobileDownloaderCard extends StatelessWidget {
  const _MobileDownloaderCard({
    required this.client,
    required this.labels,
    required this.onEdit,
    required this.onDelete,
  });

  final DownloadClientDto client;
  final _DownloaderLabels labels;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final providerName = labels.providerName;
    final libraryName = labels.libraryName;
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
        _DownloaderMetaLine(label: l10n.commonProvider, value: providerName),
        _DownloaderMetaLine(
          label: l10n.downloaderMediaLibraryLabel,
          value: libraryName,
        ),
      ],
      onTap: onEdit,
      trailingAction: AppIconButton(
        key: Key('mobile-downloader-delete-${client.id}'),
        tooltip: l10n.commonDelete,
        size: AppIconButtonSize.mini,
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

class _MobileDownloadersLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final placeholders = downloadClientPlaceholders(count: 3);
    final emptyLabels = const _DownloaderLabels(
      providerName: '',
      libraryName: '',
    );
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < placeholders.length; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            _MobileDownloaderCard(
              client: placeholders[index],
              labels: emptyLabels,
              onEdit: () {},
              onDelete: () {},
            ),
          ],
        ],
      ),
    );
  }
}
