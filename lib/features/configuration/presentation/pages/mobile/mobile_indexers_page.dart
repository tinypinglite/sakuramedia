import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_state.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_connection_test_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_connection_test_panel.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_info_block.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileIndexersPage extends ConsumerStatefulWidget {
  const MobileIndexersPage({super.key});

  @override
  ConsumerState<MobileIndexersPage> createState() => _MobileIndexersPageState();
}

class _MobileIndexersPageState extends ConsumerState<MobileIndexersPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<IndexerEntryDto> _indexers = const <IndexerEntryDto>[];
  List<DownloadClientDto> _downloadClients = const <DownloadClientDto>[];
  IndexerSettingsDto? _savedSettings;
  final Object _connectionTestScope = Object();

  bool get _hasDownloadClients => _downloadClients.isNotEmpty;

  int get _boundIndexerCount => _indexers.where(_boundClientsStillExist).length;

  int get _configuredApiKeyCount =>
      _indexers.where((entry) => entry.hasApiKey).length;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-indexers'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshData,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildBody(context)),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-indexers-create-button'),
                label: '新增索引器',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed:
                    !_isLoading && _hasDownloadClients
                        ? _handleCreateIndexer
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _MobileIndexersLoadingSection();
    }

    if (_errorMessage != null &&
        _indexers.isEmpty &&
        _downloadClients.isEmpty) {
      return AppMobileSectionError(
        key: const Key('mobile-indexers-error-state'),
        title: '索引器加载失败',
        message: _errorMessage!,
        onRetry: _retryData,
        retryButtonKey: const Key('mobile-indexers-retry-button'),
      );
    }

    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNoticeCard(
          key: const Key('mobile-indexers-overview-card'),
          title: 'Torznab 索引器负责搜索候选资源，并把资源请求投递到对应下载器。',
          description: '每个索引器可独立配置 API Key；留空的站点请求不会携带 apikey。',
          stats: [
            AppNoticeStat(
              label: 'API Key 已配置',
              value: '$_configuredApiKeyCount 个',
            ),
            AppNoticeStat(label: '索引器数', value: '${_indexers.length}'),
            AppNoticeStat(label: '已绑定下载器', value: '$_boundIndexerCount'),
          ],
        ),
        SizedBox(height: spacing.md),
        _buildConnectionTestCard(context),
        SizedBox(height: spacing.md),
        if (!_hasDownloadClients) ...[
          MobileConfigOnboardingCard(
            key: const Key('mobile-indexers-guide-downloaders'),
            title: '请先在下载器页创建下载器',
            description: '索引器需要先绑定下载器，影片详情里的资源投递才能生效。',
            actionLabel: '前往下载器',
            onActionTap:
                () => GoRouter.of(context).push(mobileSettingsDownloadersPath),
          ),
          SizedBox(height: spacing.md),
        ],
        _buildIndexersSection(context),
      ],
    );
  }

  Widget _buildConnectionTestCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final connectionTest = ref.watch(
      indexerConnectionTestProvider(_connectionTestScope),
    );

    return Container(
      key: const Key('mobile-indexers-connection-test-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IndexerConnectionTestPanel(
            key: const Key('mobile-indexers-connection-test-panel'),
            isTesting: connectionTest.isTesting,
            isTestEnabled: _isConnectionTestEnabled,
            onTest: _testConnection,
            result: connectionTest.result,
            requestError: connectionTest.requestError,
            disabledMessage: _connectionTestDisabledMessage,
            testButtonKey: const Key('mobile-indexers-connection-test-button'),
            resultKey: const Key('mobile-indexers-connection-test-result'),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexersSection(BuildContext context) {
    if (_indexers.isEmpty) {
      return const MobileConfigEmptyCard(
        key: Key('mobile-indexers-empty-state'),
        message: '还没有索引器配置',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _indexers
          .expand(
            (entry) => <Widget>[
              _buildIndexerCard(context, entry),
              if (entry != _indexers.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Widget _buildIndexerCard(BuildContext context, IndexerEntryDto entry) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final hasInvalidBinding = !_boundClientsStillExist(entry);

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
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          'API Key: ${entry.hasApiKey ? '已配置' : '未配置'}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '绑定下载器: ${entry.downloadClientNames.isEmpty ? '未匹配' : entry.downloadClientNames}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
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
              '绑定下载器已失效，请重新选择',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
          ),
        ],
      ],
      onTap: () => _handleOpenIndexerDetail(entry),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        ref.read(indexerSettingsProvider.future),
        ref.read(downloadClientsProvider.future),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings((results[0] as IndexerSettingsState).draft);
        _downloadClients = results[1] as List<DownloadClientDto>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '索引器加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _refreshData() async {
    final messages = await Future.wait<String?>([
      ref.read(indexerSettingsProvider.notifier).refresh(),
      ref.read(downloadClientsProvider.notifier).refresh(),
    ]);
    final message = messages.whereType<String>().firstOrNull;
    if (message != null) {
      if (mounted) showToast(message);
      return;
    }
    try {
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(ref.read(indexerSettingsProvider).requireValue.draft);
        _downloadClients = ref.read(downloadClientsProvider).requireValue;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '索引器加载失败，请稍后重试。'));
    }
  }

  Future<void> _retryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait<void>([
        ref.read(indexerSettingsProvider.notifier).reload(),
        ref.read(downloadClientsProvider.notifier).reload(),
      ]);
      if (!mounted) return;
      final settings = ref.read(indexerSettingsProvider).requireValue;
      final clients = ref.read(downloadClientsProvider).requireValue;
      setState(() {
        _applySettings(settings.draft);
        _downloadClients = clients;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '索引器加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _testConnection() async {
    if (!_isConnectionTestEnabled) {
      return;
    }
    final result = await ref
        .read(indexerConnectionTestProvider(_connectionTestScope).notifier)
        .testConnection(
          () => ref.read(indexerSettingsApiProvider).testConnection(),
        );
    if (!mounted || result == null) {
      return;
    }
    showToast(result.healthy ? 'Torznab 连通正常' : 'Torznab 连通性测试失败');
  }

  Future<void> _handleCreateIndexer() async {
    final saved = await showMobileIndexerEditorDrawer(
      context,
      existingEntries: _indexers,
      downloadClients: _downloadClients,
    );
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _applySettings(saved);
      _errorMessage = null;
    });
  }

  Future<void> _handleOpenIndexerDetail(IndexerEntryDto entry) async {
    final action = await showMobileIndexerDetailDrawer(
      context,
      entry: entry,
      hasInvalidBinding: !_boundClientsStillExist(entry),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MobileIndexerDetailAction.edit:
        await _handleEditIndexer(entry);
      case MobileIndexerDetailAction.delete:
        await _handleDeleteIndexer(entry);
    }
  }

  Future<void> _handleEditIndexer(IndexerEntryDto entry) async {
    final saved = await showMobileIndexerEditorDrawer(
      context,
      existingEntries: _indexers,
      downloadClients: _downloadClients,
      initialEntry: entry,
    );
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _applySettings(saved);
      _errorMessage = null;
    });
  }

  Future<void> _handleDeleteIndexer(IndexerEntryDto entry) async {
    final nextEntries = _indexers
        .where((item) => item.id != entry.id)
        .toList(growable: false);
    IndexerSettingsDto? savedSettings;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除索引器',
      message: '确认删除索引器"${entry.name}"？删除后，该索引器将无法继续把资源请求投递到当前下载器。',
      danger: true,
      confirmLabel: '删除',
      dialogKey: const Key('mobile-indexer-delete-drawer'),
      confirmKey: const Key('mobile-indexer-delete-confirm-button'),
      failureFallback: '删除索引器失败',
      onConfirm: () async {
        savedSettings = await ref
            .read(indexerSettingsProvider.notifier)
            .saveDraft(indexers: nextEntries);
      },
    );
    if (!confirmed || !mounted || savedSettings == null) {
      return;
    }
    showToast('索引器已删除');
    setState(() {
      _applySettings(savedSettings!);
      _errorMessage = null;
    });
  }

  void _applySettings(IndexerSettingsDto settings) {
    _indexers = List<IndexerEntryDto>.from(settings.indexers);
    _savedSettings = settings;
    ref
        .read(indexerConnectionTestProvider(_connectionTestScope).notifier)
        .invalidate();
  }

  bool get _hasUnsavedChanges {
    final saved = _savedSettings;
    if (saved == null) {
      return false;
    }
    if (_indexers.length != saved.indexers.length) {
      return true;
    }
    for (var index = 0; index < _indexers.length; index++) {
      final current = _indexers[index];
      final previous = saved.indexers[index];
      if (current.id != previous.id ||
          current.name != previous.name ||
          current.url != previous.url ||
          current.kind != previous.kind ||
          current.apiKey != previous.apiKey ||
          !listEquals(current.downloadClientIds, previous.downloadClientIds)) {
        return true;
      }
    }
    return false;
  }

  bool get _isConnectionTestEnabled =>
      !_isLoading &&
      !ref
          .read(indexerConnectionTestProvider(_connectionTestScope))
          .isTesting &&
      !_hasUnsavedChanges;

  String? get _connectionTestDisabledMessage {
    if (_hasUnsavedChanges) {
      return '当前配置尚未保存，保存后再测试。';
    }
    return null;
  }

  bool _boundClientsStillExist(IndexerEntryDto entry) {
    final existingIds = _downloadClients.map((client) => client.id).toSet();
    return entry.downloadClients.isNotEmpty &&
        entry.downloadClientIds.every(existingIds.contains);
  }
}

Future<IndexerSettingsDto?> showMobileIndexerEditorDrawer(
  BuildContext context, {
  required List<IndexerEntryDto> existingEntries,
  required List<DownloadClientDto> downloadClients,
  IndexerEntryDto? initialEntry,
}) {
  return showAppBottomDrawer<IndexerSettingsDto>(
    context: context,
    drawerKey: const Key('mobile-indexer-editor-drawer'),
    heightFactor: 0.8,
    builder: (drawerContext) {
      return _MobileIndexerEditorDrawer(
        existingEntries: existingEntries,
        downloadClients: downloadClients,
        initialEntry: initialEntry,
      );
    },
  );
}

Future<MobileIndexerDetailAction?> showMobileIndexerDetailDrawer(
  BuildContext context, {
  required IndexerEntryDto entry,
  required bool hasInvalidBinding,
}) {
  return showAppBottomDrawer<MobileIndexerDetailAction>(
    context: context,
    drawerKey: const Key('mobile-indexer-detail-drawer'),
    heightFactor: 0.58,
    builder: (drawerContext) {
      return _MobileIndexerDetailDrawer(
        entry: entry,
        hasInvalidBinding: hasInvalidBinding,
      );
    },
  );
}

enum MobileIndexerDetailAction { edit, delete }

class _MobileIndexersLoadingSection extends StatelessWidget {
  const _MobileIndexersLoadingSection();

  @override
  Widget build(BuildContext context) {
    final radius = context.appRadius.lgBorder;
    return Column(
      children: [
        AppSkeletonBlock(width: double.infinity, height: 172, radius: radius),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonBlock(width: double.infinity, height: 188, radius: radius),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonBlock(width: double.infinity, height: 128, radius: radius),
        SizedBox(height: context.appSpacing.sm),
        AppSkeletonBlock(width: double.infinity, height: 128, radius: radius),
      ],
    );
  }
}

class _MobileIndexerEditorDrawer extends ConsumerStatefulWidget {
  const _MobileIndexerEditorDrawer({
    required this.existingEntries,
    required this.downloadClients,
    this.initialEntry,
  });

  final List<IndexerEntryDto> existingEntries;
  final List<DownloadClientDto> downloadClients;
  final IndexerEntryDto? initialEntry;

  @override
  ConsumerState<_MobileIndexerEditorDrawer> createState() =>
      _MobileIndexerEditorDrawerState();
}

class _MobileIndexerEditorDrawerState
    extends ConsumerState<_MobileIndexerEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;
  late String _kind;
  late List<int> _selectedDownloadClientIds;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialEntry != null;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initialEntry = widget.initialEntry;
    _nameController = TextEditingController(text: initialEntry?.name ?? '');
    _urlController = TextEditingController(text: initialEntry?.url ?? '');
    _apiKeyController = TextEditingController(
      text: initialEntry?.apiKey ?? '',
    );
    _nameFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
    _kind = initialEntry?.kind ?? 'pt';
    _selectedDownloadClientIds = List<int>.of(
      initialEntry?.downloadClientIds ?? const <int>[],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑索引器' : '新增索引器',
      subtitle: '维护索引器地址、类别与下载器绑定关系。',
      submitKey: const Key('mobile-indexer-submit-button'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: IndexerEntryFormFields(
        nameController: _nameController,
        urlController: _urlController,
        apiKeyController: _apiKeyController,
        kind: _kind,
        downloadClients: widget.downloadClients,
        selectedDownloadClientIds: _selectedDownloadClientIds,
        existingEntries: widget.existingEntries,
        editingEntryId: widget.initialEntry?.id,
        enabled: !_isSubmitting,
        autovalidateMode: _autovalidateMode,
        nameFocusNode: _nameFocusNode,
        urlFocusNode: _urlFocusNode,
        onKindChanged:
            (value) => setState(() {
              _kind = value;
              if (value == 'pt') {
                final qbIds =
                    widget.downloadClients
                        .where((client) => client.isQbittorrent)
                        .map((client) => client.id)
                        .toSet();
                _selectedDownloadClientIds = _selectedDownloadClientIds
                    .where(qbIds.contains)
                    .toList(growable: false);
              }
            }),
        onDownloadClientsChanged:
            (value) => setState(() {
              _selectedDownloadClientIds = value;
            }),
        onSubmitted: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!isSupportedIndexerKind(_kind)) {
      showToast('索引器类型仅支持 pt 或 bt');
      return;
    }

    final nextEntry = IndexerEntryDto(
      id: widget.initialEntry?.id ?? 0,
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      kind: _kind,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      downloadClients: _selectedDownloadClients(),
    );
    final nextEntries = List<IndexerEntryDto>.of(widget.existingEntries);
    final existingIndex = nextEntries.indexWhere(
      (item) => item.id == widget.initialEntry?.id,
    );
    if (existingIndex >= 0) {
      nextEntries[existingIndex] = nextEntry;
    } else {
      nextEntries.add(nextEntry);
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final saved = await ref
          .read(indexerSettingsProvider.notifier)
          .saveDraft(indexers: nextEntries);
      if (!mounted) {
        return;
      }
      showToast(_isEditing ? '索引器已更新' : '索引器已创建');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: _isEditing ? '更新索引器失败' : '创建索引器失败'),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  List<IndexerBoundClientDto> _selectedDownloadClients() {
    final clientsById = <int, DownloadClientDto>{
      for (final client in widget.downloadClients) client.id: client,
    };
    return _selectedDownloadClientIds
        .map((id) => clientsById[id])
        .whereType<DownloadClientDto>()
        .map(
          (client) => IndexerBoundClientDto(
            id: client.id,
            name: client.name,
            kind: client.kind,
          ),
        )
        .toList(growable: false);
  }
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
                        weight: AppTextWeight.regular,
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
          AppInfoBlock(label: '类别', value: entry.kind.toUpperCase()),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: 'API Key',
            value: entry.hasApiKey ? '已配置' : '未配置',
          ),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: '绑定下载器',
            value:
                entry.downloadClientNames.isEmpty
                    ? '未匹配'
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
                '绑定下载器已失效，请重新选择',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
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
                  label: '编辑',
                  variant: AppButtonVariant.primary,
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(MobileIndexerDetailAction.edit),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('mobile-indexer-detail-delete-button'),
                  label: '删除',
                  variant: AppButtonVariant.danger,
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(MobileIndexerDetailAction.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
