import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_state.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_connection_test_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_connection_test_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

class IndexerSettingsSection extends ConsumerStatefulWidget {
  const IndexerSettingsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<IndexerSettingsSection> createState() =>
      _IndexerSettingsSectionState();
}

class _IndexerSettingsSectionState
    extends ConsumerState<IndexerSettingsSection> {
  final TextEditingController _searchController = TextEditingController();

  bool _isSaving = false;
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<IndexerEntryDto> _indexers = <IndexerEntryDto>[];
  List<DownloadClientDto> _downloadClients = <DownloadClientDto>[];
  final Object _connectionTestScope = Object();

  List<DownloadClientDto> get _currentDownloadClients =>
      ref.read(downloadClientsProvider).value ?? _downloadClients;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    if (widget.active) unawaited(_loadData());
  }

  @override
  void didUpdateWidget(covariant IndexerSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_initialized && !_isLoading) {
      unawaited(_loadData());
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final values = await Future.wait<Object>([
        ref.read(indexerSettingsProvider.future),
        ref.read(downloadClientsProvider.future),
      ]);
      if (!mounted) return;
      setState(() {
        _applySettings((values[0] as IndexerSettingsState).draft);
        _downloadClients = values[1] as List<DownloadClientDto>;
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '索引器配置加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _refresh() async {
    if (_isLoading || _isSaving) {
      return;
    }
    ref.invalidate(indexerSettingsProvider);
    ref.invalidate(downloadClientsProvider);
    await _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _applySettings(IndexerSettingsDto settings) {
    _indexers = List<IndexerEntryDto>.from(settings.indexers);
    ref
        .read(indexerConnectionTestProvider(_connectionTestScope).notifier)
        .invalidate();
  }

  bool get _isConnectionTestEnabled =>
      !_isSaving &&
      !ref.read(indexerConnectionTestProvider(_connectionTestScope)).isTesting;

  Future<void> _saveIndexers(
    List<IndexerEntryDto> indexers, {
    required String successToast,
  }) async {
    if (_isSaving) {
      return;
    }
    final duplicateNames = findDuplicateIndexerNames(indexers);
    if (duplicateNames.isNotEmpty) {
      showToast('索引器名称重复: ${duplicateNames.first}');
      return;
    }
    for (final item in indexers) {
      if (!isValidIndexerHttpUrl(item.url)) {
        showToast('索引器 URL 必须是合法的 http/https 地址');
        return;
      }
      if (!isSupportedIndexerKind(item.kind)) {
        showToast('索引器类型仅支持 pt 或 bt');
        return;
      }
      if (item.downloadClients.isEmpty) {
        showToast('请为每个索引器至少选择一个下载器');
        return;
      }
      final availableClientIds = _currentDownloadClients
          .map((client) => client.id)
          .toSet();
      if (!item.downloadClientIds.every(availableClientIds.contains)) {
        showToast('索引器绑定的下载器已失效，请重新选择');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final saved = await ref
          .read(indexerSettingsProvider.notifier)
          .saveDraft(indexers: indexers);
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(saved);
        _isSaving = false;
      });
      showToast(successToast);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      showToast(apiErrorMessage(error, fallback: '保存索引器配置失败'));
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

  Future<void> _createIndexer() async {
    if (_isSaving) {
      return;
    }
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder: (dialogContext) => IndexerEntryDialog(
        title: '新增索引器',
        downloadClients: _currentDownloadClients,
      ),
    );
    if (result == null) {
      return;
    }
    await _saveIndexers(
      List<IndexerEntryDto>.from(_indexers)..add(result),
      successToast: '索引器已创建',
    );
  }

  Future<void> _editIndexer(int index) async {
    if (_isSaving) {
      return;
    }
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder: (dialogContext) => IndexerEntryDialog(
        title: '编辑索引器',
        downloadClients: _currentDownloadClients,
        initialEntry: _indexers[index],
      ),
    );
    if (result == null) {
      return;
    }
    await _saveIndexers(
      List<IndexerEntryDto>.from(_indexers)..[index] = result,
      successToast: '索引器已更新',
    );
  }

  Future<void> _deleteIndexer(int index) async {
    await _saveIndexers(
      List<IndexerEntryDto>.from(_indexers)..removeAt(index),
      successToast: '索引器已删除',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) return const SizedBox.shrink();

    final content = _buildContent(context);
    return widget.active
        ? AppPageRefreshScope(onRefresh: _refresh, child: content)
        : content;
  }

  Widget _buildContent(BuildContext context) {
    final downloadClients = widget.active
        ? ref.watch(downloadClientsProvider).value ?? _downloadClients
        : _downloadClients;
    if (_isLoading) return const AppSectionSkeleton(lineCount: 5);
    if (_errorMessage != null) {
      return AppSectionError(
        title: '索引器配置加载失败',
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }
    return _buildLoaded(context, downloadClients);
  }

  Widget _buildLoaded(
    BuildContext context,
    List<DownloadClientDto> downloadClients,
  ) {
    final connectionTest = ref.watch(
      indexerConnectionTestProvider(_connectionTestScope),
    );
    final query = _searchController.text.trim().toLowerCase();
    final filteredIndexers = query.isEmpty
        ? _indexers
        : _indexers
              .where((item) {
                final source =
                    '${item.name} ${item.url} ${item.kind} '
                            '${item.apiKey ?? ''} ${item.downloadClientNames}'
                        .toLowerCase();
                return source.contains(query);
              })
              .toList(growable: false);

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppContentCard(
          title: 'Torznab 连通性',
          titleStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
          headerBottomSpacing: spacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IndexerConnectionTestPanel(
                key: const Key('configuration-indexer-connection-test-panel'),
                isTesting: connectionTest.isTesting,
                isTestEnabled: _isConnectionTestEnabled,
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
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                '索引器列表',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ),
            AppButton(
              key: const Key('configuration-indexer-create-button'),
              onPressed: downloadClients.isEmpty || _isSaving
                  ? null
                  : _createIndexer,
              icon: const Icon(Icons.add_rounded),
              label: '添加',
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        if (downloadClients.isEmpty) ...[
          SizedBox(height: spacing.sm),
          Text(
            '请先在下载器 Tab 创建下载器',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
        SizedBox(height: spacing.md),
        IndexerSearchField(controller: _searchController),
        SizedBox(height: spacing.md),
        if (filteredIndexers.isEmpty)
          IndexerEmptyState(message: query.isEmpty ? '还没有配置索引站' : '没有匹配的索引站')
        else
          AppSettingsGroup(
            children: [
              for (final item in filteredIndexers)
                IndexerEntryCard(
                  entry: item,
                  index: _indexers.indexOf(item),
                  onEdit: () {
                    if (!_isSaving) {
                      _editIndexer(_indexers.indexOf(item));
                    }
                  },
                  onDelete: () {
                    if (!_isSaving) {
                      _deleteIndexer(_indexers.indexOf(item));
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class IndexerEntryCard extends StatelessWidget {
  const IndexerEntryCard({
    super.key,
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
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'API Key: ${entry.hasApiKey ? '已配置' : '未配置'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '下载器: ${entry.downloadClientNames}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.md),
          AppInlineActionButton(
            key: Key('indexer-entry-edit-$index'),
            icon: Icons.edit_outlined,
            onTap: onEdit,
          ),
          SizedBox(width: spacing.xs),
          AppInlineActionButton(
            key: Key('indexer-entry-delete-$index'),
            icon: Icons.delete_outline,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class IndexerEntryDialog extends ConsumerStatefulWidget {
  const IndexerEntryDialog({
    super.key,
    required this.title,
    required this.downloadClients,
    this.initialEntry,
  });

  final String title;
  final List<DownloadClientDto> downloadClients;
  final IndexerEntryDto? initialEntry;

  @override
  ConsumerState<IndexerEntryDialog> createState() => _IndexerEntryDialogState();
}

class _IndexerEntryDialogState extends ConsumerState<IndexerEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late String _kind;
  late List<int> _selectedDownloadClientIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialEntry?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.initialEntry?.url ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.initialEntry?.apiKey ?? '',
    );
    _kind = widget.initialEntry?.kind ?? 'pt';
    _selectedDownloadClientIds = List<int>.of(
      widget.initialEntry?.downloadClientIds ?? const <int>[],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedDownloadClients = _selectedDownloadClients();
    if (selectedDownloadClients.isEmpty) {
      showToast('请至少选择一个仍可用的下载器');
      return;
    }
    Navigator.of(context).pop(
      IndexerEntryDto(
        id: widget.initialEntry?.id ?? 0,
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
        kind: _kind,
        apiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
        downloadClients: selectedDownloadClients,
      ),
    );
  }

  List<IndexerBoundClientDto> _selectedDownloadClients() {
    final clientsById = <int, DownloadClientDto>{
      for (final client in widget.downloadClients) client.id: client,
    };
    return _selectedDownloadClientIds
        .map((id) => clientsById[id])
        .whereType<DownloadClientDto>()
        .map(
          (client) => IndexerBoundClientDto(id: client.id, name: client.name),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;
    final spacing = context.appSpacing;

    return AppDesktopDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appLayoutTokens.dialogInsetPadding,
        vertical: context.appLayoutTokens.dialogInsetPadding,
      ),
      width: context.appLayoutTokens.dialogWidthMd,
      child: Form(
        key: _formKey,
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
            Flexible(
              child: SingleChildScrollView(
                child: IndexerEntryFormFields(
                  nameController: _nameController,
                  urlController: _urlController,
                  apiKeyController: _apiKeyController,
                  kind: _kind,
                  downloadClients: widget.downloadClients,
                  selectedDownloadClientIds: _selectedDownloadClientIds,
                  onKindChanged: (value) => setState(() {
                    _kind = value;
                  }),
                  onDownloadClientsChanged: (value) => setState(() {
                    _selectedDownloadClientIds = value;
                  }),
                  onSubmitted: _submit,
                ),
              ),
            ),
            SizedBox(height: spacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: '取消',
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                Expanded(
                  child: AppButton(
                    onPressed: widget.downloadClients.isEmpty ? null : _submit,
                    label: isEditing ? '保存' : '保存',
                    variant: AppButtonVariant.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IndexerSearchField extends StatelessWidget {
  const IndexerSearchField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: '搜索已添加的索引器...',
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

class IndexerEmptyState extends StatelessWidget {
  const IndexerEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.xl,
        vertical: context.appSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
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
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
