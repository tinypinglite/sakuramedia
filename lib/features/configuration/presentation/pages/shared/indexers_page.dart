import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_connection_test_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_state.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_connection_test_panel.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_entry_editor.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_settings_actions.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_info_block.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 索引器设置页：桌面分类页与移动子页共用 provider、动作和编辑表单。
class IndexersPage extends ConsumerStatefulWidget {
  const IndexersPage({super.key, required this.mobile, this.active = true});

  final bool mobile;
  final bool active;

  @override
  ConsumerState<IndexersPage> createState() => _IndexersPageState();
}

class _IndexersPageState extends ConsumerState<IndexersPage> {
  final TextEditingController _searchController = TextEditingController();
  final Object _connectionTestScope = Object();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      ref.read(indexerSettingsProvider.notifier).reload(),
      ref.read(downloadClientsProvider.notifier).reload(),
    ]);
  }

  Future<void> _testConnection() async {
    final result = await ref
        .read(indexerConnectionTestProvider(_connectionTestScope).notifier)
        .testConnection(
          () => ref.read(indexerSettingsApiProvider).testConnection(),
        );
    if (!mounted || result == null) return;
    final l10n = AppLocalizations.of(context);
    showToast(
      result.healthy
          ? l10n.indexerConnectionHealthy
          : l10n.indexerConnectionTestFailed,
      tone: result.healthy ? AppToastTone.success : AppToastTone.error,
    );
  }

  Future<void> _createIndexer(_IndexersData data) async {
    final entry = await showIndexerEntryEditor(
      context,
      mobile: false,
      existingEntries: data.indexers,
      downloadClients: data.clients,
    );
    if (entry == null || !mounted) return;
    await saveIndexerDraft(
      ref: ref,
      context: context,
      indexers: List<IndexerEntryDto>.of(data.indexers)..add(entry),
      successToast: AppLocalizations.of(context).indexerCreated,
    );
  }

  Future<void> _editIndexer(int index, _IndexersData data) async {
    final entry = await showIndexerEntryEditor(
      context,
      mobile: false,
      existingEntries: data.indexers,
      downloadClients: data.clients,
      initialEntry: data.indexers[index],
    );
    if (entry == null || !mounted) return;
    await saveIndexerDraft(
      ref: ref,
      context: context,
      indexers: List<IndexerEntryDto>.of(data.indexers)..[index] = entry,
      successToast: AppLocalizations.of(context).indexerUpdated,
    );
  }

  Future<void> _deleteIndexer(
    int index,
    _IndexersData data, {
    bool mobile = false,
  }) async {
    final entry = data.indexers[index];
    final l10n = AppLocalizations.of(context);
    final nextIndexers = List<IndexerEntryDto>.of(data.indexers)
      ..removeAt(index);
    if (mobile) {
      await showAppConfigDeleteConfirm(
        context: context,
        title: l10n.indexerDeleteTitle,
        message: l10n.indexerDeleteMessage(entry.name),
        dialogKey: const Key('mobile-indexer-delete-drawer'),
        confirmKey: const Key('mobile-indexer-delete-confirm-button'),
        onDelete: () async {
          await ref
              .read(indexerSettingsProvider.notifier)
              .saveDraft(indexers: nextIndexers);
        },
        successToast: l10n.indexerDeleted,
        failureFallback: l10n.indexerDeleteFailed,
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.indexerDeleteTitle,
      message: l10n.indexerDeleteMessage(entry.name),
      confirmLabel: l10n.commonDelete,
      danger: true,
      dialogKey: const Key('configuration-indexer-delete-dialog'),
      confirmKey: const Key('configuration-indexer-delete-confirm-button'),
      cancelKey: const Key('configuration-indexer-delete-cancel-button'),
    );
    if (!confirmed || !mounted) return;
    await saveIndexerDraft(
      ref: ref,
      context: context,
      indexers: nextIndexers,
      successToast: l10n.indexerDeleted,
    );
  }

  Future<void> _handleMobileEditor(
    _IndexersData data, {
    IndexerEntryDto? initialEntry,
  }) async {
    await showIndexerEntryEditor(
      context,
      mobile: true,
      existingEntries: data.indexers,
      downloadClients: data.clients,
      initialEntry: initialEntry,
    );
  }

  Future<void> _handleMobileDetail(
    IndexerEntryDto entry,
    _IndexersData data,
  ) async {
    final action = await _showMobileDetailDrawer(
      context,
      entry,
      hasInvalidBinding: !_boundClientsStillExist(entry, data.clients),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _IndexerDetailAction.edit:
        await _handleMobileEditor(data, initialEntry: entry);
      case _IndexerDetailAction.delete:
        final index = data.indexers.indexWhere((item) => item.id == entry.id);
        if (index >= 0) {
          await _deleteIndexer(index, data, mobile: true);
        }
    }
  }

  _IndexersData _readData({bool withPlaceholders = false}) {
    final settingsAsync = ref.watch(indexerSettingsProvider);
    final clientsAsync = ref.watch(downloadClientsProvider);
    final settings = settingsAsync.value;
    final clients =
        clientsAsync.value ??
        (withPlaceholders
            ? downloadClientPlaceholders()
            : const <DownloadClientDto>[]);
    final indexers =
        settings?.draft.indexers ??
        (withPlaceholders ? indexerPlaceholders() : const <IndexerEntryDto>[]);
    return _IndexersData(
      indexers: indexers,
      clients: clients,
      loading:
          (settingsAsync.isLoading && settingsAsync.value == null) ||
          (clientsAsync.isLoading && clientsAsync.value == null),
      error: settingsAsync.error ?? clientsAsync.error,
      isSaving: settings?.isSaving ?? false,
      isDirty: settings?.isDirty ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    ref.listen<AsyncValue<IndexerSettingsState>>(indexerSettingsProvider, (
      previous,
      next,
    ) {
      if (!identical(previous?.value?.draft, next.value?.draft)) {
        ref
            .read(indexerConnectionTestProvider(_connectionTestScope).notifier)
            .invalidate();
      }
    });
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final data = _readData(withPlaceholders: true);
    final l10n = AppLocalizations.of(context);
    if (!data.loading && data.error != null) {
      return AppPageRefreshScope(
        onRefresh: _refresh,
        child: AppSectionError(
          key: const Key('indexers-error-state'),
          title: l10n.indexerConfigLoadFailed,
          message: apiErrorMessage(
            data.error!,
            fallback: l10n.indexerConfigLoadFailedFallback,
            l10n: l10n,
          ),
          onRetry: _refresh,
        ),
      );
    }
    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: AppSkeletonizer(
        enabled: data.loading,
        child: _buildDesktopContent(context, data),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context, _IndexersData data) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final connectionTest = ref.watch(
      indexerConnectionTestProvider(_connectionTestScope),
    );
    final query = _searchController.text.trim().toLowerCase();
    final filteredIndexers = query.isEmpty
        ? data.indexers
        : data.indexers
              .where((item) {
                final source =
                    '${item.name} ${item.url} ${item.kind} '
                            '${item.apiKey ?? ''} ${item.downloadClientNames}'
                        .toLowerCase();
                return source.contains(query);
              })
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppContentCard(
          title: l10n.indexerTestPanelTitle,
          headerBottomSpacing: spacing.md,
          child: IndexerConnectionTestPanel(
            key: const Key('configuration-indexer-connection-test-panel'),
            isTesting: connectionTest.isTesting,
            isTestEnabled: !data.isSaving && !connectionTest.isTesting,
            onTest: _testConnection,
            result: connectionTest.result,
            requestError: connectionTest.requestError,
            testButtonKey: const Key(
              'configuration-indexer-connection-test-button',
            ),
            resultKey: const Key(
              'configuration-indexer-connection-test-result',
            ),
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.indexerListTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ),
            AppButton(
              key: const Key('configuration-indexer-create-button'),
              onPressed: data.clients.isEmpty || data.isSaving
                  ? null
                  : () => _createIndexer(data),
              icon: const Icon(Icons.add_rounded),
              label: l10n.indexerAddAction,
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        if (data.clients.isEmpty) ...[
          SizedBox(height: spacing.sm),
          Text(
            l10n.indexerCreateDownloaderHint,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
        SizedBox(height: spacing.md),
        _IndexerSearchField(controller: _searchController),
        SizedBox(height: spacing.md),
        if (filteredIndexers.isEmpty)
          _IndexerEmptyState(
            message: query.isEmpty
                ? l10n.indexerEmptyDesktop
                : l10n.indexerEmptyNoMatch,
          )
        else
          AppSettingsGroup(
            children: [
              for (final item in filteredIndexers)
                _IndexerEntryCard(
                  entry: item,
                  index: data.indexers.indexOf(item),
                  onEdit: () {
                    if (!data.isSaving) {
                      _editIndexer(data.indexers.indexOf(item), data);
                    }
                  },
                  onDelete: () {
                    if (!data.isSaving) {
                      _deleteIndexer(data.indexers.indexOf(item), data);
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final data = _readData();
    return ColoredBox(
      key: const Key('mobile-settings-indexers'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refresh,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: spacing.md, bottom: spacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: _buildMobileBody(context, data),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(top: spacing.md, bottom: spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-indexers-create-button'),
                label: l10n.indexerAdd,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: !data.loading && data.clients.isNotEmpty
                    ? () => _handleMobileEditor(data)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, _IndexersData data) {
    final l10n = AppLocalizations.of(context);
    if (data.loading) return _buildMobileLoading(context);
    if (data.error != null && data.indexers.isEmpty && data.clients.isEmpty) {
      return AppMobileSectionError(
        key: const Key('mobile-indexers-error-state'),
        title: l10n.indexerLoadFailedTitle,
        message: apiErrorMessage(
          data.error!,
          fallback: l10n.indexerLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: _refresh,
        retryButtonKey: const Key('mobile-indexers-retry-button'),
      );
    }
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileOverview(context, data),
        SizedBox(height: spacing.md),
        _buildMobileConnectionTest(context, data),
        SizedBox(height: spacing.md),
        if (data.clients.isEmpty) ...[
          MobileConfigOnboardingCard(
            key: const Key('mobile-indexers-guide-downloaders'),
            title: l10n.indexerGuideCreateDownloaderTitle,
            description: l10n.indexerGuideCreateDownloaderDescription,
            actionLabel: l10n.indexerGuideGoToDownloaders,
            onActionTap: () =>
                GoRouter.of(context).push(mobileSettingsDownloadersPath),
          ),
          SizedBox(height: spacing.md),
        ],
        if (data.indexers.isEmpty)
          MobileConfigEmptyCard(
            key: const Key('mobile-indexers-empty-state'),
            message: l10n.indexerEmpty,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: data.indexers
                .expand(
                  (entry) => <Widget>[
                    _buildMobileIndexerCard(context, entry, data),
                    if (entry != data.indexers.last)
                      SizedBox(height: spacing.sm),
                  ],
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildMobileOverview(BuildContext context, _IndexersData data) {
    final l10n = AppLocalizations.of(context);
    return AppNoticeCard(
      key: const Key('mobile-indexers-overview-card'),
      title: l10n.indexerOverviewTitle,
      description: l10n.indexerOverviewDescription,
      stats: [
        AppNoticeStat(
          label: l10n.indexerApiKeyConfigured,
          value: l10n.indexerCountValue(
            data.indexers.where((entry) => entry.hasApiKey).length,
          ),
        ),
        AppNoticeStat(
          label: l10n.indexerCountLabel,
          value: '${data.indexers.length}',
        ),
        AppNoticeStat(
          label: l10n.indexerBoundDownloadClientsLabel,
          value:
              '${data.indexers.where((entry) => _boundClientsStillExist(entry, data.clients)).length}',
        ),
      ],
    );
  }

  Widget _buildMobileConnectionTest(BuildContext context, _IndexersData data) {
    final spacing = context.appSpacing;
    final connectionTest = ref.watch(
      indexerConnectionTestProvider(_connectionTestScope),
    );
    final enabled =
        !data.isSaving && !data.isDirty && !connectionTest.isTesting;
    return AppContentCard(
      key: const Key('mobile-indexers-connection-test-card'),
      padding: EdgeInsets.all(spacing.md),
      child: IndexerConnectionTestPanel(
        key: const Key('mobile-indexers-connection-test-panel'),
        isTesting: connectionTest.isTesting,
        isTestEnabled: enabled,
        onTest: _testConnection,
        result: connectionTest.result,
        requestError: connectionTest.requestError,
        disabledMessage: data.isDirty
            ? AppLocalizations.of(context).indexerUnsavedTestHint
            : null,
        testButtonKey: const Key('mobile-indexers-connection-test-button'),
        resultKey: const Key('mobile-indexers-connection-test-result'),
      ),
    );
  }

  Widget _buildMobileLoading(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final placeholders = indexerPlaceholders(count: 3);
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNoticeCard(
            key: const Key('mobile-indexers-overview-card'),
            title: l10n.indexerOverviewTitle,
            description: l10n.indexerOverviewDescription,
            stats: [
              AppNoticeStat(
                label: l10n.indexerApiKeyConfigured,
                value: l10n.indexerCountValue(0),
              ),
              AppNoticeStat(
                label: l10n.indexerCountLabel,
                value: '${placeholders.length}',
              ),
              AppNoticeStat(
                label: l10n.indexerBoundDownloadClientsLabel,
                value: '0',
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _buildMobileConnectionTest(
            context,
            _IndexersData(
              indexers: placeholders,
              clients: const <DownloadClientDto>[],
              loading: false,
              error: null,
              isSaving: false,
              isDirty: false,
            ),
          ),
          SizedBox(height: spacing.md),
          for (final entry in placeholders) ...[
            _MobileIndexerCard(
              entry: entry,
              hasInvalidBinding: false,
              onTap: () {},
            ),
            if (entry != placeholders.last) SizedBox(height: spacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileIndexerCard(
    BuildContext context,
    IndexerEntryDto entry,
    _IndexersData data,
  ) {
    return _MobileIndexerCard(
      entry: entry,
      hasInvalidBinding: !_boundClientsStillExist(entry, data.clients),
      onTap: () => _handleMobileDetail(entry, data),
    );
  }
}

class _IndexersData {
  const _IndexersData({
    required this.indexers,
    required this.clients,
    required this.loading,
    required this.error,
    required this.isSaving,
    required this.isDirty,
  });

  final List<IndexerEntryDto> indexers;
  final List<DownloadClientDto> clients;
  final bool loading;
  final Object? error;
  final bool isSaving;
  final bool isDirty;
}

bool _boundClientsStillExist(
  IndexerEntryDto entry,
  List<DownloadClientDto> clients,
) {
  final existingIds = clients.map((client) => client.id).toSet();
  return entry.downloadClients.isNotEmpty &&
      entry.downloadClientIds.every(existingIds.contains);
}

class _IndexerEntryCard extends StatelessWidget {
  const _IndexerEntryCard({
    required this.entry,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final IndexerEntryDto entry;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: Key('indexer-entry-card-$index'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Row(
        children: [
          IndexerSourceAvatar(kind: entry.kind),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.medium,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    IndexerKindBadge(kind: entry.kind),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  entry.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  l10n.indexerApiKeyLine(
                    entry.hasApiKey
                        ? l10n.indexerConfigured
                        : l10n.indexerNotConfigured,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  l10n.indexerDownloaderLine(entry.downloadClientNames),
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
          SizedBox(width: spacing.md),
          AppIconButton(
            key: Key('indexer-entry-edit-$index'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            size: AppIconButtonSize.inline,
            iconColor: context.appTextPalette.secondary,
            onPressed: onEdit,
          ),
          SizedBox(width: spacing.xs),
          AppIconButton(
            key: Key('indexer-entry-delete-$index'),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.commonDelete,
            size: AppIconButtonSize.inline,
            iconColor: context.appTextPalette.secondary,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _MobileIndexerCard extends StatelessWidget {
  const _MobileIndexerCard({
    required this.entry,
    required this.hasInvalidBinding,
    required this.onTap,
  });

  final IndexerEntryDto entry;
  final bool hasInvalidBinding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return MobileEntityListCard(
      outerKey: Key('mobile-indexer-card-${entry.id}'),
      bodyKey: Key('mobile-indexer-card-body-${entry.id}'),
      leading: IndexerSourceAvatar(kind: entry.kind),
      title: Text(
        entry.name,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      titleTrailing: IndexerKindBadge(kind: entry.kind),
      body: [
        SizedBox(height: spacing.xs),
        Text(
          entry.url,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          l10n.indexerApiKeyLine(
            entry.hasApiKey
                ? l10n.indexerConfigured
                : l10n.indexerNotConfigured,
          ),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          l10n.indexerBoundDownloadClientsLine(
            entry.downloadClientNames.isEmpty
                ? l10n.indexerNotMatched
                : entry.downloadClientNames,
          ),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        if (hasInvalidBinding) ...[
          SizedBox(height: spacing.sm),
          Container(
            key: Key('mobile-indexer-invalid-binding-${entry.id}'),
            width: double.infinity,
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              color: colors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Text(
              l10n.indexerBoundDownloaderInvalid,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.primary,
              ),
            ),
          ),
        ],
      ],
      onTap: onTap,
    );
  }
}

class _IndexerSearchField extends StatelessWidget {
  const _IndexerSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: AppLocalizations.of(context).indexerSearchHint,
      prefix: Icon(
        Icons.search_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: context.appTextPalette.muted,
      ),
      onChanged: (_) {},
      isDense: false,
    );
  }
}

class _IndexerEmptyState extends StatelessWidget {
  const _IndexerEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.xl,
        vertical: context.appSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.travel_explore_outlined,
            size: context.appComponentTokens.iconSizeMd,
            color: context.appTextPalette.muted,
          ),
          SizedBox(height: context.appSpacing.sm),
          Text(
            message,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _IndexerDetailAction { edit, delete }

Future<_IndexerDetailAction?> _showMobileDetailDrawer(
  BuildContext context,
  IndexerEntryDto entry, {
  required bool hasInvalidBinding,
}) {
  return showAppBottomDrawer<_IndexerDetailAction>(
    context: context,
    drawerKey: const Key('mobile-indexer-detail-drawer'),
    heightFactor: 0.58,
    builder: (_) => _MobileIndexerDetailDrawer(
      entry: entry,
      hasInvalidBinding: hasInvalidBinding,
    ),
  );
}

class _MobileIndexerDetailDrawer extends StatelessWidget {
  const _MobileIndexerDetailDrawer({
    required this.entry,
    required this.hasInvalidBinding,
  });

  final IndexerEntryDto entry;
  final bool hasInvalidBinding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      entry.url,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IndexerKindBadge(kind: entry.kind),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppInfoBlock(
            label: l10n.indexerKindLabel,
            value: entry.kind.toUpperCase(),
          ),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: 'API Key',
            value: entry.hasApiKey
                ? l10n.indexerConfigured
                : l10n.indexerNotConfigured,
          ),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: l10n.indexerBoundDownloadClientLabel,
            value: entry.downloadClientNames.isEmpty
                ? l10n.indexerNotMatched
                : entry.downloadClientNames,
          ),
          if (hasInvalidBinding) ...[
            SizedBox(height: spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: context.appColors.warningSurface,
                borderRadius: context.appRadius.mdBorder,
              ),
              child: Text(
                l10n.indexerBoundDownloaderInvalid,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
          ],
          SizedBox(height: spacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('mobile-indexer-detail-edit-button'),
                  label: l10n.commonEdit,
                  variant: AppButtonVariant.primary,
                  onPressed: () =>
                      Navigator.of(context).pop(_IndexerDetailAction.edit),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('mobile-indexer-detail-delete-button'),
                  label: l10n.commonDelete,
                  variant: AppButtonVariant.danger,
                  onPressed: () =>
                      Navigator.of(context).pop(_IndexerDetailAction.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
