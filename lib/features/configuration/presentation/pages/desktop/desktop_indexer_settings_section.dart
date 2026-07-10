import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/section_loader_mixin.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/indexer_connection_test_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/indexer_connection_test_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class IndexerSettingsSection extends StatefulWidget {
  const IndexerSettingsSection({super.key, required this.active});

  final bool active;

  @override
  State<IndexerSettingsSection> createState() => _IndexerSettingsSectionState();
}

class _IndexerSettingsSectionState extends State<IndexerSettingsSection>
    with
        SectionLoaderMixin<
          (IndexerSettingsDto, List<DownloadClientDto>),
          IndexerSettingsSection
        > {
  static const List<String> _supportedTypes = <String>['jackett'];

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSaving = false;
  String _selectedType = _supportedTypes.first;
  List<IndexerEntryDto> _indexers = <IndexerEntryDto>[];
  List<DownloadClientDto> _downloadClients = <DownloadClientDto>[];
  IndexerSettingsDto? _savedSettings;
  late final IndexerConnectionTestController _connectionTestController;

  @override
  bool get isSectionActive => widget.active;

  @override
  Future<(IndexerSettingsDto, List<DownloadClientDto>)>
  fetchSectionData() async {
    final futures = await Future.wait<Object>([
      context.read<IndexerSettingsApi>().getSettings(),
      context.read<DownloadClientsApi>().getClients(),
    ]);
    return (
      futures[0] as IndexerSettingsDto,
      futures[1] as List<DownloadClientDto>,
    );
  }

  @override
  void applySectionData((IndexerSettingsDto, List<DownloadClientDto>) data) {
    _applySettings(data.$1);
    _downloadClients = List<DownloadClientDto>.from(data.$2);
  }

  @override
  String get sectionLoadErrorFallback => '索引器配置加载失败，请稍后重试。';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _apiKeyController.addListener(_handleApiKeyChanged);
    _connectionTestController = IndexerConnectionTestController(
      runTest: () => context.read<IndexerSettingsApi>().testConnection(),
    )..addListener(_handleConnectionTestChanged);
    tryLoadIfActive();
  }

  @override
  void didUpdateWidget(covariant IndexerSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    tryLoadIfActive();
  }

  @override
  void dispose() {
    _apiKeyController.removeListener(_handleApiKeyChanged);
    _apiKeyController.dispose();
    _connectionTestController
      ..removeListener(_handleConnectionTestChanged)
      ..dispose();
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

  void _handleApiKeyChanged() {
    if (!mounted) {
      return;
    }
    _connectionTestController.invalidate();
  }

  void _handleConnectionTestChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applySettings(IndexerSettingsDto settings) {
    _selectedType =
        settings.type.isEmpty ? _supportedTypes.first : settings.type;
    _apiKeyController.removeListener(_handleApiKeyChanged);
    _apiKeyController.text = settings.apiKey;
    _apiKeyController.addListener(_handleApiKeyChanged);
    _indexers = List<IndexerEntryDto>.from(settings.indexers);
    _savedSettings = settings;
    _connectionTestController.invalidate(notify: false);
  }

  bool get _hasUnsavedChanges {
    final saved = _savedSettings;
    if (saved == null) {
      return false;
    }
    if (_selectedType.trim() != saved.type.trim() ||
        _apiKeyController.text.trim() != saved.apiKey.trim() ||
        _indexers.length != saved.indexers.length) {
      return true;
    }
    for (var index = 0; index < _indexers.length; index++) {
      final current = _indexers[index];
      final previous = saved.indexers[index];
      if (current.id != previous.id ||
          current.name != previous.name ||
          current.url != previous.url ||
          current.kind != previous.kind ||
          current.downloadClientId != previous.downloadClientId ||
          current.downloadClientName != previous.downloadClientName) {
        return true;
      }
    }
    return false;
  }

  bool get _isConnectionTestEnabled =>
      !_isSaving && !_connectionTestController.isTesting && !_hasUnsavedChanges;

  String? get _connectionTestDisabledMessage {
    if (_hasUnsavedChanges) {
      return '当前配置尚未保存，保存后再测试。';
    }
    return null;
  }

  Future<void> _saveSettings() async {
    final type = _selectedType.trim();
    final apiKey = _apiKeyController.text.trim();

    if (!_supportedTypes.contains(type)) {
      showToast('索引器类型暂不支持');
      return;
    }
    if (apiKey.isEmpty) {
      showToast('请输入 API Key');
      return;
    }
    final duplicateNames = findDuplicateIndexerNames(_indexers);
    if (duplicateNames.isNotEmpty) {
      showToast('索引器名称重复: ${duplicateNames.first}');
      return;
    }
    for (final item in _indexers) {
      if (!isValidIndexerHttpUrl(item.url)) {
        showToast('索引器 URL 必须是合法的 http/https 地址');
        return;
      }
      if (!isSupportedIndexerKind(item.kind)) {
        showToast('索引器类型仅支持 pt 或 bt');
        return;
      }
      if (item.downloadClientId <= 0) {
        showToast('请为每个索引器选择下载器');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final saved = await context.read<IndexerSettingsApi>().updateSettings(
        UpdateIndexerSettingsPayload(
          type: type,
          apiKey: apiKey,
          indexers: _indexers,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(saved);
        _isSaving = false;
      });
      showToast('索引器配置已保存');
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
    final result = await _connectionTestController.testConnection();
    if (!mounted || result == null) {
      return;
    }
    showToast(result.healthy ? 'Jackett 连通正常' : 'Jackett 连通性测试失败');
  }

  Future<void> _createIndexer() async {
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder:
          (dialogContext) => IndexerEntryDialog(
            title: '新增索引器',
            downloadClients: _downloadClients,
          ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _indexers = List<IndexerEntryDto>.from(_indexers)..add(result);
      _connectionTestController.invalidate(notify: false);
    });
  }

  Future<void> _editIndexer(int index) async {
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder:
          (dialogContext) => IndexerEntryDialog(
            title: '编辑索引器',
            downloadClients: _downloadClients,
            initialEntry: _indexers[index],
          ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _indexers = List<IndexerEntryDto>.from(_indexers)..[index] = result;
      _connectionTestController.invalidate(notify: false);
    });
  }

  void _deleteIndexer(int index) {
    setState(() {
      _indexers = List<IndexerEntryDto>.from(_indexers)..removeAt(index);
      _connectionTestController.invalidate(notify: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildSectionStates(
      errorTitle: '索引器配置加载失败',
      skeletonLineCount: 5,
      buildLoaded: _buildLoaded,
    );
  }

  Widget _buildLoaded(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredIndexers =
        query.isEmpty
            ? _indexers
            : _indexers
                .where((item) {
                  final source =
                      '${item.name} ${item.url} ${item.kind} ${item.downloadClientName}'
                          .toLowerCase();
                  return source.contains(query);
                })
                .toList(growable: false);

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppContentCard(
          title: 'API 密钥',
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
              AppPasswordField(
                controller: _apiKeyController,
                hintText: '请输入 Jackett API Key',
                showLabel: '显示 API 密钥',
                hideLabel: '隐藏 API 密钥',
              ),
              SizedBox(height: spacing.sm),
              Text(
                '该密钥用于与 Jackett 后端进行身份验证',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              SizedBox(height: spacing.lg),
              IndexerConnectionTestPanel(
                key: const Key('configuration-indexer-connection-test-panel'),
                isTesting: _connectionTestController.isTesting,
                isTestEnabled: _isConnectionTestEnabled,
                onTest: _testConnection,
                result: _connectionTestController.result,
                requestError: _connectionTestController.requestError,
                disabledMessage: _connectionTestDisabledMessage,
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
              onPressed: _downloadClients.isEmpty ? null : _createIndexer,
              icon: const Icon(Icons.add_rounded),
              label: '添加',
              size: AppButtonSize.small,
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        if (_downloadClients.isEmpty) ...[
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
                  onEdit: () => _editIndexer(_indexers.indexOf(item)),
                  onDelete: () => _deleteIndexer(_indexers.indexOf(item)),
                ),
            ],
          ),
        SizedBox(height: spacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              key: const Key('configuration-indexer-save-button'),
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving ? null : const Icon(Icons.save_outlined),
              label: _isSaving ? '保存中' : '保存配置',
              isLoading: _isSaving,
              variant: AppButtonVariant.primary,
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
                  '下载器: ${entry.downloadClientName}',
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

class IndexerEntryDialog extends StatefulWidget {
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
  State<IndexerEntryDialog> createState() => _IndexerEntryDialogState();
}

class _IndexerEntryDialogState extends State<IndexerEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late String _kind;
  int? _selectedDownloadClientId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialEntry?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.initialEntry?.url ?? '',
    );
    _kind = widget.initialEntry?.kind ?? 'pt';
    _selectedDownloadClientId = widget.initialEntry?.downloadClientId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final downloadClientName = _downloadClientNameFor(
      _selectedDownloadClientId,
    );
    Navigator.of(context).pop(
      IndexerEntryDto(
        id: widget.initialEntry?.id ?? 0,
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
        kind: _kind,
        downloadClientId: _selectedDownloadClientId!,
        downloadClientName: downloadClientName,
      ),
    );
  }

  String _downloadClientNameFor(int? clientId) {
    if (clientId == null) {
      return '';
    }
    for (final client in widget.downloadClients) {
      if (client.id == clientId) {
        return client.name;
      }
    }
    return '';
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
            IndexerEntryFormFields(
              nameController: _nameController,
              urlController: _urlController,
              kind: _kind,
              downloadClients: widget.downloadClients,
              selectedDownloadClientId: _selectedDownloadClientId,
              onKindChanged: (value) => setState(() => _kind = value),
              onDownloadClientChanged:
                  (value) => setState(() {
                    _selectedDownloadClientId = value;
                  }),
              onSubmitted: _submit,
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
