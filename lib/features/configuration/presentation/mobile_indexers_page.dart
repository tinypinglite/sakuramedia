import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/indexer_entry_form.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class MobileIndexersPage extends StatefulWidget {
  const MobileIndexersPage({super.key});

  @override
  State<MobileIndexersPage> createState() => _MobileIndexersPageState();
}

class _MobileIndexersPageState extends State<MobileIndexersPage> {
  late final TextEditingController _apiKeyController;
  bool _isLoading = true;
  bool _isSavingApiKey = false;
  bool _obscureApiKey = true;
  String? _errorMessage;
  String _settingsType = 'jackett';
  List<IndexerEntryDto> _indexers = const <IndexerEntryDto>[];
  List<DownloadClientDto> _downloadClients = const <DownloadClientDto>[];

  bool get _hasDownloadClients => _downloadClients.isNotEmpty;

  int get _boundIndexerCount =>
      _indexers.where((item) => _resolveDownloadClient(item) != null).length;

  String get _resolvedSettingsType {
    final trimmed = _settingsType.trim();
    return trimmed.isEmpty ? 'jackett' : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
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
            child: AppPullToRefresh(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  spacing.lg,
                ),
                children: [_buildBody(context)],
              ),
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
        _downloadClients.isEmpty &&
        _apiKeyController.text.trim().isEmpty) {
      return _MobileIndexersErrorSection(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileIndexersOverviewCard(
          indexerCount: _indexers.length,
          boundIndexerCount: _boundIndexerCount,
          hasApiKey: _apiKeyController.text.trim().isNotEmpty,
        ),
        SizedBox(height: spacing.md),
        _buildApiKeyCard(context),
        SizedBox(height: spacing.md),
        if (!_hasDownloadClients) ...[
          _MobileIndexersGuideCard(
            onOpenDownloaders:
                () => GoRouter.of(context).push(mobileSettingsDownloadersPath),
          ),
          SizedBox(height: spacing.md),
        ],
        _buildIndexersSection(context),
      ],
    );
  }

  Widget _buildApiKeyCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-indexers-api-key-card'),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jackett API Key',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppBadge(
                label: _apiKeyController.text.trim().isEmpty ? '待配置' : '已配置',
                tone:
                    _apiKeyController.text.trim().isEmpty
                        ? AppBadgeTone.warning
                        : AppBadgeTone.success,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Text(
            '用于与 Jackett 后端通信，保存后索引器条目会复用这份凭证。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('mobile-indexers-api-key-field'),
            controller: _apiKeyController,
            hintText: '请输入 Jackett API Key',
            obscureText: _obscureApiKey,
            enabled: !_isSavingApiKey,
            suffix: AppIconButton(
              key: const Key('mobile-indexers-api-key-visibility-button'),
              tooltip: _obscureApiKey ? '显示 API Key' : '隐藏 API Key',
              semanticLabel: _obscureApiKey ? '显示 API Key' : '隐藏 API Key',
              size: AppIconButtonSize.compact,
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed:
                  _isSavingApiKey
                      ? null
                      : () => setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      }),
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('mobile-indexers-api-key-save-button'),
              label: '保存 API Key',
              variant: AppButtonVariant.primary,
              isLoading: _isSavingApiKey,
              onPressed: _saveApiKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexersSection(BuildContext context) {
    if (_indexers.isEmpty) {
      return Container(
        key: const Key('mobile-indexers-empty-state'),
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.md,
          vertical: context.appSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: context.appRadius.lgBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: const AppEmptyState(message: '还没有索引器配置'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _indexers
          .expand(
            (entry) => <Widget>[
              _MobileIndexerCard(
                entry: entry,
                downloadClient: _resolveDownloadClient(entry),
                onTap: () => _handleOpenIndexerDetail(entry),
              ),
              if (entry != _indexers.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        context.read<IndexerSettingsApi>().getSettings(),
        context.read<DownloadClientsApi>().getClients(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(results[0] as IndexerSettingsDto);
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
    try {
      final results = await Future.wait<Object>([
        context.read<IndexerSettingsApi>().getSettings(),
        context.read<DownloadClientsApi>().getClients(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(results[0] as IndexerSettingsDto);
        _downloadClients = results[1] as List<DownloadClientDto>;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '索引器加载失败，请稍后重试。'));
    }
  }

  Future<void> _saveApiKey() async {
    if (_isSavingApiKey) {
      return;
    }
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      showToast('请输入 API Key');
      return;
    }

    setState(() {
      _isSavingApiKey = true;
    });

    try {
      final saved = await context.read<IndexerSettingsApi>().updateSettings(
        UpdateIndexerSettingsPayload(
          type: _resolvedSettingsType,
          apiKey: apiKey,
          indexers: _indexers,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(saved);
        _isSavingApiKey = false;
      });
      showToast('API Key 已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingApiKey = false;
      });
      showToast(apiErrorMessage(error, fallback: '保存 API Key 失败'));
    }
  }

  Future<void> _handleCreateIndexer() async {
    final saved = await showMobileIndexerEditorDrawer(
      context,
      settingsType: _resolvedSettingsType,
      apiKey: _apiKeyController.text.trim(),
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
      downloadClient: _resolveDownloadClient(entry),
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
      settingsType: _resolvedSettingsType,
      apiKey: _apiKeyController.text.trim(),
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
    final saved = await showMobileDeleteIndexerDrawer(
      context,
      settingsType: _resolvedSettingsType,
      apiKey: _apiKeyController.text.trim(),
      entry: entry,
      existingEntries: _indexers,
    );
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _applySettings(saved);
      _errorMessage = null;
    });
  }

  void _applySettings(IndexerSettingsDto settings) {
    _settingsType = settings.type.trim().isEmpty ? 'jackett' : settings.type;
    _apiKeyController.text = settings.apiKey;
    _indexers = List<IndexerEntryDto>.from(settings.indexers);
  }

  DownloadClientDto? _resolveDownloadClient(IndexerEntryDto entry) {
    for (final client in _downloadClients) {
      if (client.id == entry.downloadClientId) {
        return client;
      }
    }
    return null;
  }
}

Future<IndexerSettingsDto?> showMobileIndexerEditorDrawer(
  BuildContext context, {
  required String settingsType,
  required String apiKey,
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
        settingsType: settingsType,
        apiKey: apiKey,
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
  required DownloadClientDto? downloadClient,
}) {
  return showAppBottomDrawer<MobileIndexerDetailAction>(
    context: context,
    drawerKey: const Key('mobile-indexer-detail-drawer'),
    heightFactor: 0.58,
    builder: (drawerContext) {
      return _MobileIndexerDetailDrawer(
        entry: entry,
        downloadClient: downloadClient,
      );
    },
  );
}

Future<IndexerSettingsDto?> showMobileDeleteIndexerDrawer(
  BuildContext context, {
  required String settingsType,
  required String apiKey,
  required IndexerEntryDto entry,
  required List<IndexerEntryDto> existingEntries,
}) {
  return showAppBottomDrawer<IndexerSettingsDto>(
    context: context,
    drawerKey: const Key('mobile-indexer-delete-drawer'),
    maxHeightFactor: 0.42,
    builder: (drawerContext) {
      return _MobileDeleteIndexerDrawer(
        settingsType: settingsType,
        apiKey: apiKey,
        entry: entry,
        existingEntries: existingEntries,
      );
    },
  );
}

enum MobileIndexerDetailAction { edit, delete }

class _MobileIndexersOverviewCard extends StatelessWidget {
  const _MobileIndexersOverviewCard({
    required this.indexerCount,
    required this.boundIndexerCount,
    required this.hasApiKey,
  });

  final int indexerCount;
  final int boundIndexerCount;
  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-indexers-overview-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jackett 负责统一管理索引器入口，并把资源请求投递到对应下载器。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '先确认 API Key，再补齐每个索引器和下载器的绑定关系。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              const Expanded(
                child: _MobileIndexerOverviewStat(
                  label: '接入类型',
                  value: 'Jackett',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _MobileIndexerOverviewStat(
                  label: 'API Key 状态',
                  value: hasApiKey ? '已配置' : '待配置',
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: _MobileIndexerOverviewStat(
                  label: '索引器数',
                  value: '$indexerCount',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _MobileIndexerOverviewStat(
                  label: '已绑定下载器',
                  value: '$boundIndexerCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileIndexerOverviewStat extends StatelessWidget {
  const _MobileIndexerOverviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileIndexersGuideCard extends StatelessWidget {
  const _MobileIndexersGuideCard({required this.onOpenDownloaders});

  final VoidCallback onOpenDownloaders;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Container(
      key: const Key('mobile-indexers-guide-downloaders'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '请先在下载器页创建下载器',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '索引器需要先绑定下载器，影片详情里的资源投递才能生效。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppButton(
            label: '前往下载器',
            size: AppButtonSize.xSmall,
            onPressed: onOpenDownloaders,
          ),
        ],
      ),
    );
  }
}

class _MobileIndexerCard extends StatelessWidget {
  const _MobileIndexerCard({
    required this.entry,
    required this.downloadClient,
    required this.onTap,
  });

  final IndexerEntryDto entry;
  final DownloadClientDto? downloadClient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final hasInvalidBinding =
        entry.downloadClientId > 0 && downloadClient == null;

    return Container(
      key: Key('mobile-indexer-card-${entry.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mobile-indexer-card-body-${entry.id}'),
          borderRadius: context.appRadius.lgBorder,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IndexerSourceAvatar(kind: entry.kind),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                weight: AppTextWeight.semibold,
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
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        '绑定下载器: ${downloadClient?.name ?? '未匹配'}',
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
                          key: Key(
                            'mobile-indexer-invalid-binding-${entry.id}',
                          ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileIndexersLoadingSection extends StatelessWidget {
  const _MobileIndexersLoadingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MobileIndexersSkeletonCard(height: 172),
        SizedBox(height: context.appSpacing.md),
        const _MobileIndexersSkeletonCard(height: 188),
        SizedBox(height: context.appSpacing.md),
        const _MobileIndexersSkeletonCard(height: 128),
        SizedBox(height: context.appSpacing.sm),
        const _MobileIndexersSkeletonCard(height: 128),
      ],
    );
  }
}

class _MobileIndexersSkeletonCard extends StatelessWidget {
  const _MobileIndexersSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.lgBorder,
      ),
    );
  }
}

class _MobileIndexersErrorSection extends StatelessWidget {
  const _MobileIndexersErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-indexers-error-state'),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(message: '索引器加载失败'),
          SizedBox(height: spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('mobile-indexers-retry-button'),
              label: '重试',
              variant: AppButtonVariant.primary,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileIndexerEditorDrawer extends StatefulWidget {
  const _MobileIndexerEditorDrawer({
    required this.settingsType,
    required this.apiKey,
    required this.existingEntries,
    required this.downloadClients,
    this.initialEntry,
  });

  final String settingsType;
  final String apiKey;
  final List<IndexerEntryDto> existingEntries;
  final List<DownloadClientDto> downloadClients;
  final IndexerEntryDto? initialEntry;

  @override
  State<_MobileIndexerEditorDrawer> createState() =>
      _MobileIndexerEditorDrawerState();
}

class _MobileIndexerEditorDrawerState
    extends State<_MobileIndexerEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _urlFocusNode;
  late String _kind;
  late int? _selectedDownloadClientId;
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
    _nameFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
    _kind = initialEntry?.kind ?? 'pt';
    _selectedDownloadClientId = initialEntry?.downloadClientId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _nameFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? '编辑索引器' : '新增索引器',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                '维护索引器地址、类别与下载器绑定关系。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
              IndexerEntryFormFields(
                nameController: _nameController,
                urlController: _urlController,
                kind: _kind,
                downloadClients: widget.downloadClients,
                selectedDownloadClientId: _selectedDownloadClientId,
                existingEntries: widget.existingEntries,
                editingEntryId: widget.initialEntry?.id,
                enabled: !_isSubmitting,
                autovalidateMode: _autovalidateMode,
                nameFocusNode: _nameFocusNode,
                urlFocusNode: _urlFocusNode,
                onKindChanged: (value) => setState(() => _kind = value),
                onDownloadClientChanged:
                    (value) => setState(() {
                      _selectedDownloadClientId = value;
                    }),
                onSubmitted: _submit,
              ),
              SizedBox(height: spacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '取消',
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      key: const Key('mobile-indexer-submit-button'),
                      label: '保存',
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    if (widget.apiKey.trim().isEmpty) {
      showToast('请先保存 API Key');
      return;
    }

    final nextEntry = IndexerEntryDto(
      id: widget.initialEntry?.id ?? 0,
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      kind: _kind,
      downloadClientId: _selectedDownloadClientId ?? 0,
      downloadClientName: _downloadClientNameFor(_selectedDownloadClientId),
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
      final saved = await context.read<IndexerSettingsApi>().updateSettings(
        UpdateIndexerSettingsPayload(
          type: widget.settingsType,
          apiKey: widget.apiKey,
          indexers: nextEntries,
        ),
      );
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
}

class _MobileIndexerDetailDrawer extends StatelessWidget {
  const _MobileIndexerDetailDrawer({
    required this.entry,
    required this.downloadClient,
  });

  final IndexerEntryDto entry;
  final DownloadClientDto? downloadClient;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final hasInvalidBinding =
        entry.downloadClientId > 0 && downloadClient == null;

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
          _MobileIndexerDetailInfoBlock(
            label: '类别',
            value: entry.kind.toUpperCase(),
          ),
          SizedBox(height: spacing.sm),
          _MobileIndexerDetailInfoBlock(
            label: '绑定下载器',
            value: downloadClient?.name ?? '未匹配',
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

class _MobileIndexerDetailInfoBlock extends StatelessWidget {
  const _MobileIndexerDetailInfoBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDeleteIndexerDrawer extends StatefulWidget {
  const _MobileDeleteIndexerDrawer({
    required this.settingsType,
    required this.apiKey,
    required this.entry,
    required this.existingEntries,
  });

  final String settingsType;
  final String apiKey;
  final IndexerEntryDto entry;
  final List<IndexerEntryDto> existingEntries;

  @override
  State<_MobileDeleteIndexerDrawer> createState() =>
      _MobileDeleteIndexerDrawerState();
}

class _MobileDeleteIndexerDrawerState
    extends State<_MobileDeleteIndexerDrawer> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '删除索引器',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '确认删除索引器“${widget.entry.name}”？删除后，该索引器将无法继续把资源请求投递到当前下载器。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '取消',
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('mobile-indexer-delete-confirm-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                isLoading: _isSubmitting,
                onPressed: _deleteIndexer,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteIndexer() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final nextEntries = widget.existingEntries
        .where((item) => item.id != widget.entry.id)
        .toList(growable: false);

    try {
      final saved = await context.read<IndexerSettingsApi>().updateSettings(
        UpdateIndexerSettingsPayload(
          type: widget.settingsType,
          apiKey: widget.apiKey,
          indexers: nextEntries,
        ),
      );
      if (!mounted) {
        return;
      }
      showToast('索引器已删除');
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '删除索引器失败'));
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
