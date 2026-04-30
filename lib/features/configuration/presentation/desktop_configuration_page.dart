import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/account_profile_controller.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/desktop_llm_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/media_library_form.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

class DesktopConfigurationPage extends StatefulWidget {
  const DesktopConfigurationPage({super.key});

  @override
  State<DesktopConfigurationPage> createState() =>
      _DesktopConfigurationPageState();
}

class _DesktopConfigurationPageState extends State<DesktopConfigurationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 0;
  int _mediaLibrariesRevision = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this)
      ..addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_selectedIndex == _tabController.index) {
      return;
    }
    setState(() {
      _selectedIndex = _tabController.index;
    });
  }

  void _handleMediaLibrariesChanged() {
    setState(() {
      _mediaLibrariesRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      title: '',
      child: Column(
        key: const Key('configuration-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTabBar(
            controller: _tabController,
            tabs: const [
              Tab(key: Key('configuration-tab-license'), text: '数据源'),
              Tab(key: Key('configuration-tab-media-libraries'), text: '媒体库'),
              Tab(
                key: Key('configuration-tab-collection-features'),
                text: '合集特征',
              ),
              Tab(key: Key('configuration-tab-llm'), text: 'LLM 配置'),
              Tab(key: Key('configuration-tab-account-security'), text: '账号安全'),
              Tab(key: Key('configuration-tab-downloads'), text: '下载器'),
              Tab(key: Key('configuration-tab-indexers'), text: '索引器'),
              Tab(key: Key('configuration-tab-playlists'), text: '播放列表'),
            ],
          ),
          SizedBox(height: context.appSpacing.xl),
          IndexedStack(
            index: _selectedIndex,
            children: [
              _MetadataProviderLicenseTab(active: _selectedIndex == 0),
              _MediaLibrariesTab(
                active: _selectedIndex == 1,
                onLibrariesChanged: _handleMediaLibrariesChanged,
              ),
              _CollectionNumberFeaturesTab(active: _selectedIndex == 2),
              DesktopLlmSettingsSection(active: _selectedIndex == 3),
              const _AccountSecuritySection(),
              _DownloadClientsTab(
                active: _selectedIndex == 5,
                librariesRevision: _mediaLibrariesRevision,
              ),
              _IndexerSettingsTab(active: _selectedIndex == 6),
              _PlaylistsTab(active: _selectedIndex == 7),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaLibrariesTab extends StatefulWidget {
  const _MediaLibrariesTab({
    required this.active,
    required this.onLibrariesChanged,
  });

  final bool active;
  final VoidCallback onLibrariesChanged;

  @override
  State<_MediaLibrariesTab> createState() => _MediaLibrariesTabState();
}

class _MediaLibrariesTabState extends State<_MediaLibrariesTab> {
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _loadLibraries();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaLibrariesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadLibraries();
    }
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final libraries = await context.read<MediaLibrariesApi>().getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '媒体库加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _createLibrary() async {
    final payload = await showDialog<CreateMediaLibraryPayload>(
      context: context,
      builder: (dialogContext) => const _MediaLibraryDialog(title: '新增媒体库'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<MediaLibrariesApi>().createLibrary(payload);
      showToast('媒体库已创建');
      widget.onLibrariesChanged();
      await _loadLibraries();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '创建媒体库失败'));
    }
  }

  Future<void> _editLibrary(MediaLibraryDto library) async {
    final payload = await showDialog<UpdateMediaLibraryPayload>(
      context: context,
      builder:
          (dialogContext) =>
              _MediaLibraryDialog(title: '编辑媒体库', initialLibrary: library),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<MediaLibrariesApi>().updateLibrary(
        libraryId: library.id,
        payload: payload,
      );
      showToast('媒体库已更新');
      widget.onLibrariesChanged();
      await _loadLibraries();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '更新媒体库失败'));
    }
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AppDesktopDialog(
            width: dialogContext.appLayoutTokens.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除媒体库',
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s18,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.lg),
                Text('确认删除媒体库“${library.name}”？该操作不可恢复。'),
                SizedBox(height: dialogContext.appSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        label: '取消',
                      ),
                    ),
                    SizedBox(width: dialogContext.appSpacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        label: '删除',
                        variant: AppButtonVariant.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await context.read<MediaLibrariesApi>().deleteLibrary(library.id);
      showToast('媒体库已删除');
      widget.onLibrariesChanged();
      await _loadLibraries();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '删除媒体库失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 4);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '媒体库加载失败',
        message: _errorMessage!,
        onRetry: _loadLibraries,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '媒体库 (Media Libraries)',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            AppButton(
              key: const Key('configuration-media-library-create-button'),
              onPressed: _createLibrary,
              icon: const Icon(Icons.add_rounded),
              label: '新增媒体库',
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.md),
        Text(
          '媒体库用于维护本地媒体存储根路径，下载器等模块会依赖这里的路径配置。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        if (_libraries.isEmpty)
          const AppEmptyState(message: '还没有媒体库')
        else
          _LineSection(
            children: _libraries
                .map(
                  (library) => _MediaLibraryCard(
                    library: library,
                    onEdit: () => _editLibrary(library),
                    onDelete: () => _deleteLibrary(library),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _CollectionNumberFeaturesTab extends StatefulWidget {
  const _CollectionNumberFeaturesTab({required this.active});

  final bool active;

  @override
  State<_CollectionNumberFeaturesTab> createState() =>
      _CollectionNumberFeaturesTabState();
}

class _CollectionNumberFeaturesTabState
    extends State<_CollectionNumberFeaturesTab> {
  late final TextEditingController _collectionNumberFeaturesController;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _applySyncNow = true;
  String? _errorMessage;
  CollectionNumberFeaturesSyncStatsDto? _syncStats;

  @override
  void initState() {
    super.initState();
    _collectionNumberFeaturesController = TextEditingController();
    if (widget.active) {
      _loadFeatures();
    }
  }

  @override
  void didUpdateWidget(covariant _CollectionNumberFeaturesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadFeatures();
    }
  }

  @override
  void dispose() {
    _collectionNumberFeaturesController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings =
          await context.read<CollectionNumberFeaturesApi>().getFeatures();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyFeatures(settings);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '合集番号特征加载失败，请稍后重试。');
      });
    }
  }

  void _applyFeatures(CollectionNumberFeaturesDto settings) {
    _collectionNumberFeaturesController.text = settings.features.join('\n');
    _syncStats = settings.syncStats;
  }

  Future<void> _saveFeatures() async {
    if (_isSaving) {
      return;
    }

    final features = _parseCollectionNumberFeaturesInput(
      _collectionNumberFeaturesController.text,
    );

    setState(() {
      _isSaving = true;
    });
    try {
      final settings = await context
          .read<CollectionNumberFeaturesApi>()
          .updateFeatures(
            UpdateCollectionNumberFeaturesPayload(features: features),
            applyNow: _applySyncNow,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyFeatures(settings);
        _errorMessage = null;
        _isSaving = false;
      });
      showToast(_applySyncNow ? '已保存并完成合集重算' : '合集番号特征已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      showToast(_apiMessage(error, fallback: '保存合集番号特征失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 5);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '合集番号特征加载失败',
        message: _errorMessage!,
        onRetry: _loadFeatures,
      );
    }

    final syncStats = _syncStats;
    final spacing = context.appSpacing;

    return AppContentCard(
      title: '合集番号特征',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每行输入一个番号特征，用于判定影片是否为合集。保存时可选择是否立即触发全库重算。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          AppTextField(
            fieldKey: const Key('configuration-collection-features-field'),
            controller: _collectionNumberFeaturesController,
            maxLines: 8,
            minLines: 6,
            hintText: '例如:\nFC2\nOFJE\nDVAJ',
          ),
          SizedBox(height: spacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '保存后动作',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 260,
                      child: AppSelectField<bool>(
                        key: const Key(
                          'configuration-collection-apply-now-field',
                        ),
                        value: _applySyncNow,
                        size: AppSelectFieldSize.compact,
                        items: const [
                          DropdownMenuItem<bool>(
                            value: true,
                            child: Text('保存并立即重算合集'),
                          ),
                          DropdownMenuItem<bool>(
                            value: false,
                            child: Text('仅保存特征配置'),
                          ),
                        ],
                        onChanged:
                            (value) => setState(() {
                              _applySyncNow = value ?? true;
                            }),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    SizedBox(
                      width: 260,
                      child: AppButton(
                        key: const Key(
                          'configuration-collection-features-save-button',
                        ),
                        onPressed: _isSaving ? null : _saveFeatures,
                        icon:
                            _isSaving ? null : const Icon(Icons.save_outlined),
                        label: _isSaving ? '保存中' : '保存特征',
                        variant: AppButtonVariant.primary,
                        isLoading: _isSaving,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (syncStats != null) ...[
            SizedBox(height: spacing.lg),
            Text(
              '最近一次即时重算结果',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                _InfoPill(label: '影片总数', value: '${syncStats.totalMovies}'),
                _InfoPill(label: '匹配数量', value: '${syncStats.matchedCount}'),
                _InfoPill(
                  label: '更新为合集',
                  value: '${syncStats.updatedToCollectionCount}',
                ),
                _InfoPill(
                  label: '更新为单体',
                  value: '${syncStats.updatedToSingleCount}',
                ),
                _InfoPill(label: '未变化', value: '${syncStats.unchangedCount}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataProviderLicenseTab extends StatefulWidget {
  const _MetadataProviderLicenseTab({required this.active});

  final bool active;

  @override
  State<_MetadataProviderLicenseTab> createState() =>
      _MetadataProviderLicenseTabState();
}

class _MetadataProviderLicenseTabState
    extends State<_MetadataProviderLicenseTab> {
  late final TextEditingController _activationCodeController;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isActivating = false;
  bool _isSyncingAuthorization = false;
  bool _isTestingConnectivity = false;
  bool _obscureActivationCode = true;
  String? _errorMessage;
  MetadataProviderLicenseStatusDto? _status;
  MetadataProviderLicenseConnectivityTestDto? _connectivityTest;

  MetadataProviderLicenseApi get _api =>
      context.read<MetadataProviderLicenseApi>();

  bool get _hasBusyAction =>
      _isLoading ||
      _isActivating ||
      _isSyncingAuthorization ||
      _isTestingConnectivity;

  @override
  void initState() {
    super.initState();
    _activationCodeController = TextEditingController();
    if (widget.active) {
      _loadStatus();
    }
  }

  @override
  void didUpdateWidget(covariant _MetadataProviderLicenseTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _api.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '授权状态加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _testConnectivity() async {
    if (_hasBusyAction) {
      return;
    }

    setState(() {
      _isTestingConnectivity = true;
    });

    try {
      final result = await _api.testConnectivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivityTest = result;
        _isTestingConnectivity = false;
      });
      showToast(result.ok ? '授权中心连接正常' : '授权中心连接异常');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivityTest = null;
        _isTestingConnectivity = false;
      });
      showToast(_apiMessage(error, fallback: '授权中心连接测试失败'));
    }
  }

  Future<void> _syncAuthorization() async {
    if (_hasBusyAction) {
      return;
    }

    setState(() {
      _isSyncingAuthorization = true;
    });

    try {
      final status = await _api.syncAuthorization();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _errorMessage = null;
        _initialized = true;
        _isSyncingAuthorization = false;
      });
      showToast('授权状态已同步');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSyncingAuthorization = false;
      });
      showToast(_apiMessage(error, fallback: '同步授权失败'));
    }
  }

  Future<void> _activate() async {
    if (_hasBusyAction) {
      return;
    }
    final activationCode = _activationCodeController.text.trim();
    if (activationCode.isEmpty) {
      showToast('请输入激活码');
      return;
    }

    setState(() {
      _isActivating = true;
    });

    try {
      final status = await _api.activate(activationCode: activationCode);
      if (!mounted) {
        return;
      }
      _activationCodeController.clear();
      setState(() {
        _status = status;
        _errorMessage = null;
        _initialized = true;
        _isActivating = false;
      });
      showToast('授权已激活');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _activationCodeController.clear();
      setState(() {
        _isActivating = false;
      });
      showToast(_apiMessage(error, fallback: '激活授权失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    return AppContentCard(
      key: const Key('configuration-license-card'),
      title: '数据源授权',
      padding: EdgeInsets.all(context.appSpacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: context.appSpacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 5);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '授权状态加载失败',
        message: _errorMessage!,
        onRetry: _loadStatus,
      );
    }

    final spacing = context.appSpacing;
    final formTokens = context.appFormTokens;
    final status = _status;
    final statusDescription = _licenseStatusDescription(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '数据源负责 DMM、JavDB、MissAV 等外部元数据能力，需要完成授权后使用。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            SizedBox(width: spacing.md),
            _buildStatusBadge(status),
          ],
        ),
        SizedBox(height: spacing.lg),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            _InfoPill(label: '授权状态', value: _licenseStatusLabel(status)),
            _InfoPill(label: '授权有效期', value: _formatLicenseValidUntil(status)),
            _InfoPill(label: '授权中心', value: _connectivityStatusLabel()),
          ],
        ),
        if (statusDescription != null) ...[
          SizedBox(height: spacing.lg),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: context.appColors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
              border: Border.all(color: context.appColors.borderSubtle),
            ),
            child: Text(
              statusDescription,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.warning,
              ),
            ),
          ),
        ],
        SizedBox(height: spacing.lg),
        _buildDiagnostics(context),
        SizedBox(height: spacing.xl),
        Text(
          '激活授权',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '激活码仅用于本次请求，前端不会保存，后端也不会写入配置文件。请妥善保管激活码，避免泄露给他人。同一个激活码同一时间仅能激活一个实例；若后续用于激活其他实例，当前实例将会失效。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.md),
        Text(
          '激活码',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: formTokens.labelGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppTextField(
                fieldKey: const Key('configuration-license-activation-field'),
                controller: _activationCodeController,
                hintText: 'SMB-XXXX-XXXX-XXXX',
                obscureText: _obscureActivationCode,
                enabled: !_hasBusyAction,
                suffix: AppIconButton(
                  key: const Key(
                    'configuration-license-activation-visibility-button',
                  ),
                  tooltip: _obscureActivationCode ? '显示激活码' : '隐藏激活码',
                  semanticLabel: _obscureActivationCode ? '显示激活码' : '隐藏激活码',
                  size: AppIconButtonSize.compact,
                  icon: Icon(
                    _obscureActivationCode
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed:
                      _hasBusyAction
                          ? null
                          : () => setState(() {
                            _obscureActivationCode = !_obscureActivationCode;
                          }),
                ),
              ),
            ),
            SizedBox(width: spacing.md),
            AppButton(
              key: const Key('configuration-license-refresh-button'),
              onPressed: _hasBusyAction ? null : _loadStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: '刷新状态',
            ),
            SizedBox(width: spacing.sm),
            AppButton(
              key: const Key('configuration-license-connectivity-button'),
              onPressed: _hasBusyAction ? null : _testConnectivity,
              icon:
                  _isTestingConnectivity
                      ? null
                      : const Icon(Icons.cloud_sync_outlined),
              label: _isTestingConnectivity ? '检测中' : '测试连接',
              isLoading: _isTestingConnectivity,
            ),
            SizedBox(width: spacing.sm),
            AppButton(
              key: const Key('configuration-license-sync-button'),
              onPressed: _hasBusyAction ? null : _syncAuthorization,
              icon:
                  _isSyncingAuthorization
                      ? null
                      : const Icon(Icons.sync_rounded),
              label: _isSyncingAuthorization ? '同步中' : '同步授权',
              isLoading: _isSyncingAuthorization,
            ),
            SizedBox(width: spacing.sm),
            AppButton(
              key: const Key('configuration-license-activate-button'),
              onPressed: _hasBusyAction ? null : _activate,
              icon: _isActivating ? null : const Icon(Icons.verified_outlined),
              label: _isActivating ? '激活中' : '激活授权',
              variant: AppButtonVariant.primary,
              isLoading: _isActivating,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnostics(BuildContext context) {
    final status = _status;
    final connectivity = _connectivityTest;
    final spacing = context.appSpacing;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('configuration-license-diagnostics'),
          tilePadding: EdgeInsets.symmetric(horizontal: spacing.md),
          childrenPadding: EdgeInsets.fromLTRB(
            spacing.md,
            0,
            spacing.md,
            spacing.md,
          ),
          title: Text(
            '诊断信息',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.secondary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  _InfoPill(label: '实例 ID', value: status?.instanceId ?? '未提供'),
                  _InfoPill(
                    label: '错误码',
                    value: _diagnosticValue(status?.errorCode),
                  ),
                  _InfoPill(
                    label: '后端说明',
                    value: _diagnosticValue(status?.message),
                  ),
                  _InfoPill(
                    label: '授权中心 URL',
                    value: _diagnosticValue(connectivity?.url),
                  ),
                  _InfoPill(
                    label: '代理',
                    value:
                        connectivity == null
                            ? '未检测'
                            : (connectivity.proxyEnabled ? '已启用' : '未启用'),
                  ),
                  _InfoPill(
                    label: '耗时',
                    value:
                        connectivity == null
                            ? '未检测'
                            : '${connectivity.elapsedMs} ms',
                  ),
                  _InfoPill(
                    label: 'HTTP 状态',
                    value: connectivity?.statusCode?.toString() ?? '未提供',
                  ),
                  _InfoPill(
                    label: '连接错误',
                    value: _diagnosticValue(connectivity?.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(MetadataProviderLicenseStatusDto? status) {
    final label = _licenseStatusLabel(status);
    final tone = switch (label) {
      '已激活' => AppBadgeTone.success,
      '授权待同步' => AppBadgeTone.warning,
      '未激活' => AppBadgeTone.warning,
      '授权已到期' => AppBadgeTone.error,
      '授权不可用' => AppBadgeTone.error,
      _ => AppBadgeTone.neutral,
    };
    return AppBadge(label: label, tone: tone, size: AppBadgeSize.compact);
  }

  String _licenseStatusLabel(MetadataProviderLicenseStatusDto? status) {
    if (status == null) {
      return '未提供';
    }
    if (status.active) {
      return '已激活';
    }
    if (!status.configured) {
      return '未配置';
    }
    final errorCode = status.errorCode?.trim();
    if (errorCode == 'license_expired' ||
        _isUnixSecondsExpired(status.licenseValidUntil)) {
      return '授权已到期';
    }
    if (status.licenseValidUntil != null) {
      return '授权待同步';
    }
    if (errorCode == 'license_required') {
      return '未激活';
    }
    if (errorCode == null || errorCode.isEmpty) {
      return '未激活';
    }
    return '授权不可用';
  }

  String? _licenseStatusDescription(MetadataProviderLicenseStatusDto? status) {
    final label = _licenseStatusLabel(status);
    if (label == '授权待同步') {
      return '你的授权仍在有效期内，但当前设备需要重新同步授权后才能使用外部数据源。';
    }
    if (label == '授权已到期') {
      return '授权已到期，请使用新的激活码重新激活后继续使用外部数据源。';
    }
    if (label == '授权不可用') {
      return _licenseErrorSummary(status);
    }
    return null;
  }

  String _connectivityStatusLabel() {
    if (_isTestingConnectivity) {
      return '检测中';
    }
    final result = _connectivityTest;
    if (result == null) {
      return '未检测';
    }
    return result.ok ? '连接正常' : '连接异常';
  }

  String _licenseErrorSummary(MetadataProviderLicenseStatusDto? status) {
    final parts = <String>[];
    final errorCode = status?.errorCode?.trim();
    final message = status?.message?.trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      parts.add('错误码: $errorCode');
    }
    if (message != null && message.isNotEmpty) {
      parts.add('说明: $message');
    }
    return parts.isEmpty ? '授权暂不可用' : parts.join(' · ');
  }
}

class _AccountSecuritySection extends StatefulWidget {
  const _AccountSecuritySection();

  @override
  State<_AccountSecuritySection> createState() =>
      _AccountSecuritySectionState();
}

class _AccountSecuritySectionState extends State<_AccountSecuritySection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  late final AccountProfileController _profileController;
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _hasAttemptedUsernameSubmit = false;

  bool get _canSubmitUsername =>
      !_profileController.isLoading &&
      !_profileController.isSaving &&
      _profileController.account != null;

  @override
  void initState() {
    super.initState();
    _profileController = AccountProfileController(
      accountApi: context.read<AccountApi>(),
    );
    _usernameController =
        TextEditingController()..addListener(_handleUsernameChanged);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _profileController.dispose();
    _usernameController
      ..removeListener(_handleUsernameChanged)
      ..dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await _profileController.load();
    if (!mounted) {
      return;
    }
    _usernameController.text = _profileController.account?.username ?? '';
  }

  void _handleUsernameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitUsername() async {
    if (_profileController.isSaving) {
      return;
    }

    if (!_hasAttemptedUsernameSubmit) {
      setState(() {
        _hasAttemptedUsernameSubmit = true;
      });
    }

    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final saved = await _profileController.saveUsername(
      _usernameController.text,
    );
    if (!mounted) {
      return;
    }

    if (saved) {
      _usernameController.text = _profileController.account?.username ?? '';
      showToast('用户名已更新');
      return;
    }

    final message = _profileController.errorMessage;
    if (message != null && message.isNotEmpty) {
      showToast(message);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final accountApi = context.read<AccountApi>();
      final authApi = context.read<AuthApi>();
      final username =
          (_profileController.account?.username.trim().isNotEmpty ?? false)
              ? _profileController.account!.username.trim()
              : (await accountApi.getAccount()).username.trim();

      await accountApi.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      try {
        await authApi.login(
          username: username,
          password: _newPasswordController.text.trim(),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        showToast('密码已修改，但新密码登录校验失败，请重新登录确认');
        return;
      }

      if (!mounted) {
        return;
      }
      showToast('密码已更新，请重新登录');
      await context.read<SessionStore>().clearSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(_apiMessage(error, fallback: '修改密码失败'));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _reset() {
    if (_isSubmitting) {
      return;
    }

    _formKey.currentState?.reset();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _obscureCurrentPassword = true;
      _obscureNewPassword = true;
      _obscureConfirmPassword = true;
    });
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入当前密码';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final nextPassword = value?.trim() ?? '';
    if (nextPassword.isEmpty) {
      return '请输入新密码';
    }
    if (nextPassword == _currentPasswordController.text.trim()) {
      return '新密码不能与当前密码相同';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value?.trim() ?? '';
    if (confirmPassword.isEmpty) {
      return '请再次输入新密码';
    }
    if (confirmPassword != _newPasswordController.text.trim()) {
      return '两次输入的新密码不一致';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _profileController,
          builder: (context, _) => _buildAccountProfileCard(context),
        ),
        SizedBox(height: spacing.xl),
        _buildPasswordCard(context),
      ],
    );
  }

  Widget _buildAccountProfileCard(BuildContext context) {
    final spacing = context.appSpacing;
    final account = _profileController.account;

    return AppContentCard(
      title: '账号资料',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _profileFormKey,
        autovalidateMode:
            _hasAttemptedUsernameSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_profileController.isLoading && account == null)
              const _AccountProfileLoadingBlock()
            else if (_profileController.errorMessage != null && account == null)
              _AccountProfileErrorBlock(
                message: _profileController.errorMessage!,
                onRetry: _loadProfile,
              )
            else ...[
              Text(
                '用户名用于登录和账号识别，保存后当前登录态保持不变。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              if (account != null) ...[
                SizedBox(height: spacing.lg),
                _AccountProfileSummary(account: account),
              ],
              SizedBox(height: spacing.lg),
              AppTextField(
                fieldKey: const Key('configuration-username-field'),
                controller: _usernameController,
                label: '用户名',
                hintText: '请输入新的用户名',
                enabled: !_profileController.isSaving,
                validator: _validateUsername,
              ),
              if (_profileController.errorMessage != null &&
                  account != null) ...[
                SizedBox(height: spacing.sm),
                Text(
                  _profileController.errorMessage!,
                  key: const Key('configuration-username-error-text'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ],
              SizedBox(height: spacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  key: const Key('configuration-username-submit-button'),
                  onPressed: _canSubmitUsername ? _submitUsername : null,
                  label: '保存用户名',
                  variant: AppButtonVariant.primary,
                  isLoading: _profileController.isSaving,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context) {
    final spacing = context.appSpacing;

    return AppContentCard(
      title: '修改密码',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '修改密码后将立即退出当前登录，需要使用新密码重新登录。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: spacing.lg),
            AppTextField(
              fieldKey: const Key('configuration-password-current-field'),
              controller: _currentPasswordController,
              label: '当前密码',
              obscureText: _obscureCurrentPassword,
              validator: _validateCurrentPassword,
              suffix: _PasswordVisibilityButton(
                obscureText: _obscureCurrentPassword,
                onPressed:
                    () => setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    }),
              ),
            ),
            SizedBox(height: spacing.lg),
            AppTextField(
              fieldKey: const Key('configuration-password-new-field'),
              controller: _newPasswordController,
              label: '新密码',
              obscureText: _obscureNewPassword,
              validator: _validateNewPassword,
              suffix: _PasswordVisibilityButton(
                obscureText: _obscureNewPassword,
                onPressed:
                    () => setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    }),
              ),
            ),
            SizedBox(height: spacing.lg),
            AppTextField(
              fieldKey: const Key('configuration-password-confirm-field'),
              controller: _confirmPasswordController,
              label: '确认新密码',
              obscureText: _obscureConfirmPassword,
              validator: _validateConfirmPassword,
              suffix: _PasswordVisibilityButton(
                obscureText: _obscureConfirmPassword,
                onPressed:
                    () => setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }),
              ),
            ),
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  key: const Key('configuration-password-reset-button'),
                  onPressed: _isSubmitting ? null : _reset,
                  label: '重置',
                ),
                SizedBox(width: spacing.md),
                AppButton(
                  key: const Key('configuration-password-submit-button'),
                  onPressed: _submit,
                  label: '修改密码',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountProfileLoadingBlock extends StatelessWidget {
  const _AccountProfileLoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountProfileSkeleton(height: 48),
        SizedBox(height: context.appSpacing.md),
        _AccountProfileSkeleton(height: 44),
      ],
    );
  }
}

class _AccountProfileErrorBlock extends StatelessWidget {
  const _AccountProfileErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          key: const Key('configuration-username-retry-button'),
          label: '重试',
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _AccountProfileSummary extends StatelessWidget {
  const _AccountProfileSummary({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.md,
      runSpacing: spacing.sm,
      children: [
        _AccountProfilePill(label: '当前用户名', value: account.username),
        _AccountProfilePill(
          label: '创建时间',
          value: _formatAccountDate(account.createdAt),
        ),
        _AccountProfilePill(
          label: '上次登录',
          value: _formatAccountDate(account.lastLoginAt),
        ),
      ],
    );
  }
}

class _AccountProfilePill extends StatelessWidget {
  const _AccountProfilePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('configuration-account-profile-$label'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountProfileSkeleton extends StatelessWidget {
  const _AccountProfileSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.obscureText,
    required this.onPressed,
  });

  final bool obscureText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      onPressed: onPressed,
      tooltip: obscureText ? '显示密码' : '隐藏密码',
      icon: Icon(
        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: context.appComponentTokens.iconSizeSm,
      ),
    );
  }
}

class _DownloadClientsTab extends StatefulWidget {
  const _DownloadClientsTab({
    required this.active,
    required this.librariesRevision,
  });

  final bool active;
  final int librariesRevision;

  @override
  State<_DownloadClientsTab> createState() => _DownloadClientsTabState();
}

class _DownloadClientsTabState extends State<_DownloadClientsTab> {
  bool _initialized = false;
  bool _isLoading = false;
  bool _needsReload = false;
  String? _errorMessage;
  List<DownloadClientDto> _clients = const <DownloadClientDto>[];
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];

  @override
  void didUpdateWidget(covariant _DownloadClientsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.librariesRevision != oldWidget.librariesRevision) {
      _needsReload = true;
    }
    if (widget.active && (_needsReload || !_initialized) && !_isLoading) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        context.read<DownloadClientsApi>().getClients(),
        context.read<MediaLibrariesApi>().getLibraries(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _initialized = true;
        _needsReload = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _needsReload = false;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '下载器配置加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _createClient() async {
    final api = context.read<DownloadClientsApi>();
    final payload = await showDialog<CreateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) =>
              _DownloadClientDialog(libraries: _libraries, title: '添加下载器'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await api.createClient(payload);
      showToast('下载器已创建');
      await _loadData();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '创建下载器失败'));
    }
  }

  Future<void> _editClient(DownloadClientDto client) async {
    final api = context.read<DownloadClientsApi>();
    final payload = await showDialog<UpdateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) => _DownloadClientDialog(
            libraries: _libraries,
            title: '编辑下载器',
            initialClient: client,
          ),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await api.updateClient(clientId: client.id, payload: payload);
      showToast('下载器已更新');
      await _loadData();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '更新下载器失败'));
    }
  }

  Future<void> _deleteClient(DownloadClientDto client) async {
    final api = context.read<DownloadClientsApi>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AppDesktopDialog(
            width: dialogContext.appLayoutTokens.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除下载器',
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s18,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.lg),
                Text('确认删除下载器“${client.name}”？该操作不会删除下载任务。'),
                SizedBox(height: dialogContext.appSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        label: '取消',
                      ),
                    ),
                    SizedBox(width: dialogContext.appSpacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        label: '删除',
                        variant: AppButtonVariant.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await api.deleteClient(client.id);
      showToast('下载器已删除');
      await _loadData();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '删除下载器失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 4);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '下载器配置加载失败',
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    final librariesById = <int, MediaLibraryDto>{
      for (final library in _libraries) library.id: library,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_libraries.isEmpty) ...[
          Text(
            '当前没有可用媒体库，创建下载器前请先在后端配置媒体库。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ).copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        SizedBox(height: context.appSpacing.lg),
        if (_clients.isEmpty)
          const _EmptyPanel(message: '还没有下载器配置')
        else
          _LineSection(
            children: _clients
                .map(
                  (client) => _DownloadClientCard(
                    client: client,
                    mediaLibrary: librariesById[client.mediaLibraryId],
                    onEdit: () => _editClient(client),
                    onDelete: () => _deleteClient(client),
                  ),
                )
                .toList(growable: false),
          ),
        SizedBox(height: context.appSpacing.lg),
        Align(
          alignment: Alignment.bottomRight,
          child: AppButton(
            key: const Key('configuration-download-client-create-button'),
            label: '新建下载器',
            icon: const Icon(Icons.add_rounded),
            variant: AppButtonVariant.primary,
            onPressed: _libraries.isEmpty ? null : _createClient,
          ),
        ),
      ],
    );
  }
}

class _DownloadClientCard extends StatelessWidget {
  const _DownloadClientCard({
    required this.client,
    required this.mediaLibrary,
    required this.onEdit,
    required this.onDelete,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatUpdatedAt(client.updatedAt);

    return Container(
      key: Key('download-client-card-${client.id}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s18,
                        weight: AppTextWeight.semibold,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.xs),
                    Text(
                      client.baseUrl,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: context.appSpacing.sm,
                runSpacing: context.appSpacing.sm,
                children: [
                  AppButton(
                    key: Key('download-client-edit-${client.id}'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: '编辑',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.ghost,
                  ),
                  AppButton(
                    key: Key('download-client-delete-${client.id}'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: '删除',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.ghost,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Wrap(
            spacing: context.appSpacing.md,
            runSpacing: context.appSpacing.md,
            children: [
              _InfoPill(label: '用户名', value: client.username),
              _InfoPill(
                label: '媒体库',
                value:
                    mediaLibrary == null
                        ? '未匹配 (${client.mediaLibraryId})'
                        : mediaLibrary!.name,
              ),
              _InfoPill(label: 'qBittorrent保存路径', value: client.clientSavePath),
              _InfoPill(label: '本地访问路径', value: client.localRootPath),
              _InfoPill(label: '密码', value: client.hasPassword ? '已设置' : '未设置'),
              _InfoPill(label: '更新时间', value: dateLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistsTab extends StatefulWidget {
  const _PlaylistsTab({required this.active});

  final bool active;

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<PlaylistDto> _playlists = const <PlaylistDto>[];

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _loadPlaylists();
    }
  }

  @override
  void didUpdateWidget(covariant _PlaylistsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadPlaylists();
    }
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlists = await context.read<PlaylistsApi>().getPlaylists(
        includeSystem: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playlists = playlists
            .where((playlist) => !playlist.isSystem)
            .toList(growable: false);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '播放列表加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _createPlaylist() async {
    final created = await showCreatePlaylistDialog(context);
    if (!mounted || created == null) {
      return;
    }

    showToast('播放列表已创建');
    await _loadPlaylists();
  }

  Future<void> _editPlaylist(PlaylistDto playlist) async {
    if (!playlist.isMutable) {
      return;
    }

    final payload = await showDialog<UpdatePlaylistPayload>(
      context: context,
      builder:
          (dialogContext) =>
              _PlaylistDialog(title: '编辑播放列表', initialPlaylist: playlist),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<PlaylistsApi>().updatePlaylist(
        playlistId: playlist.id,
        payload: payload,
      );
      showToast('播放列表已更新');
      await _loadPlaylists();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '更新播放列表失败'));
    }
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    if (!playlist.isDeletable) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AppDesktopDialog(
            width: dialogContext.appLayoutTokens.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除播放列表',
                  style: resolveAppTextStyle(
                    dialogContext,
                    size: AppTextSize.s18,
                  ),
                ),
                SizedBox(height: dialogContext.appSpacing.lg),
                Text('确认删除播放列表“${playlist.name}”？该操作不可恢复。'),
                SizedBox(height: dialogContext.appSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        label: '取消',
                      ),
                    ),
                    SizedBox(width: dialogContext.appSpacing.md),
                    Expanded(
                      child: AppButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        label: '删除',
                        variant: AppButtonVariant.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await context.read<PlaylistsApi>().deletePlaylist(playlist.id);
      showToast('播放列表已删除');
      await _loadPlaylists();
    } catch (error) {
      showToast(_apiMessage(error, fallback: '删除播放列表失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 4);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '播放列表加载失败',
        message: _errorMessage!,
        onRetry: _loadPlaylists,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_playlists.isEmpty)
          const _EmptyPanel(message: '还没有自定义播放列表')
        else
          _LineSection(
            children: _playlists
                .map(
                  (playlist) => _PlaylistCard(
                    playlist: playlist,
                    onEdit:
                        playlist.isMutable
                            ? () => _editPlaylist(playlist)
                            : null,
                    onDelete:
                        playlist.isDeletable
                            ? () => _deletePlaylist(playlist)
                            : null,
                  ),
                )
                .toList(growable: false),
          ),
        SizedBox(height: context.appSpacing.lg),
        Align(
          alignment: Alignment.bottomRight,
          child: AppButton(
            key: const Key('configuration-playlist-create-button'),
            label: '新建播放列表',
            icon: const Icon(Icons.add_rounded),
            variant: AppButtonVariant.primary,
            onPressed: _createPlaylist,
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onEdit,
    required this.onDelete,
  });

  final PlaylistDto playlist;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final description = playlist.description.trim();

    return Container(
      key: Key('playlist-card-${playlist.id}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s18,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: context.appSpacing.xs),
                      Text(
                        description,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                Wrap(
                  spacing: context.appSpacing.sm,
                  runSpacing: context.appSpacing.sm,
                  children: [
                    if (onEdit != null)
                      AppButton(
                        key: Key('playlist-edit-${playlist.id}'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: '编辑',
                        size: AppButtonSize.small,
                        variant: AppButtonVariant.ghost,
                      ),
                    if (onDelete != null)
                      AppButton(
                        key: Key('playlist-delete-${playlist.id}'),
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: '删除',
                        size: AppButtonSize.small,
                        variant: AppButtonVariant.ghost,
                      ),
                  ],
                ),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          Wrap(
            spacing: context.appSpacing.md,
            runSpacing: context.appSpacing.md,
            children: [
              _InfoPill(label: '影片数', value: '${playlist.movieCount}'),
              _InfoPill(label: '类型', value: playlist.kind),
              _InfoPill(
                label: '更新时间',
                value: _formatUpdatedAt(playlist.updatedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistDialog extends StatefulWidget {
  const _PlaylistDialog({required this.title, required this.initialPlaylist});

  final String title;
  final PlaylistDto initialPlaylist;

  @override
  State<_PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<_PlaylistDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlaylist.name);
    _descriptionController = TextEditingController(
      text: widget.initialPlaylist.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      UpdatePlaylistPayload(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppDesktopDialog(
      width: context.appComponentTokens.playlistDialogWidth,
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
            const _DialogFieldLabel(label: '名称'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('configuration-playlist-name-field'),
              controller: _nameController,
              hintText: '例如：稍后再看',
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? '请输入播放列表名称'
                          : null,
            ),
            SizedBox(height: spacing.lg),
            const _DialogFieldLabel(label: '描述'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('configuration-playlist-description-field'),
              controller: _descriptionController,
              hintText: '描述可选',
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
                    onPressed: _submit,
                    label: '保存',
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

class _MediaLibraryCard extends StatelessWidget {
  const _MediaLibraryCard({
    required this.library,
    required this.onEdit,
    required this.onDelete,
  });

  final MediaLibraryDto library;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final layoutTokens = context.appLayoutTokens;

    return Container(
      key: Key('media-library-card-${library.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: layoutTokens.panelIconContainerSize,
            height: layoutTokens.panelIconContainerSize,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.folder_open_outlined,
              size: context.appComponentTokens.iconSizeLg,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  library.name,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  library.rootPath,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  'ID: ${library.id}',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  '更新时间: ${_formatUpdatedAt(library.updatedAt)}',
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
          SizedBox(width: context.appSpacing.md),
          Wrap(
            spacing: context.appSpacing.xs,
            runSpacing: context.appSpacing.xs,
            children: [
              _IndexerActionButton(
                key: Key('media-library-edit-${library.id}'),
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              _IndexerActionButton(
                key: Key('media-library-delete-${library.id}'),
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaLibraryDialog extends StatefulWidget {
  const _MediaLibraryDialog({required this.title, this.initialLibrary});

  final String title;
  final MediaLibraryDto? initialLibrary;

  @override
  State<_MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends State<_MediaLibraryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _rootPathController;

  bool get _isEditing => widget.initialLibrary != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _rootPathController = TextEditingController(
      text: widget.initialLibrary?.rootPath ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      rootPathController: _rootPathController,
    );
    if (_isEditing) {
      Navigator.of(context).pop(value.toUpdatePayload());
      return;
    }

    Navigator.of(context).pop(value.toCreatePayload());
  }

  @override
  Widget build(BuildContext context) {
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
            MediaLibraryFormFields(
              nameController: _nameController,
              rootPathController: _rootPathController,
              labelBuilder: (context, label) => _DialogFieldLabel(label: label),
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
                    onPressed: _submit,
                    label: '保存',
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

class _IndexerSettingsTab extends StatefulWidget {
  const _IndexerSettingsTab({required this.active});

  final bool active;

  @override
  State<_IndexerSettingsTab> createState() => _IndexerSettingsTabState();
}

class _IndexerSettingsTabState extends State<_IndexerSettingsTab> {
  static const List<String> _supportedTypes = <String>['jackett'];

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _initialized = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  String? _errorMessage;
  String _selectedType = _supportedTypes.first;
  List<IndexerEntryDto> _indexers = <IndexerEntryDto>[];
  List<DownloadClientDto> _downloadClients = <DownloadClientDto>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    if (widget.active) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(covariant _IndexerSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadTabData();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
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

  Future<void> _loadTabData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait<Object>([
        context.read<IndexerSettingsApi>().getSettings(),
        context.read<DownloadClientsApi>().getClients(),
      ]);
      final settings = futures[0] as IndexerSettingsDto;
      final downloadClients = futures[1] as List<DownloadClientDto>;
      if (!mounted) {
        return;
      }
      setState(() {
        _applySettings(settings);
        _downloadClients = List<DownloadClientDto>.from(downloadClients);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = _apiMessage(error, fallback: '索引器配置加载失败，请稍后重试。');
      });
    }
  }

  void _applySettings(IndexerSettingsDto settings) {
    _selectedType =
        settings.type.isEmpty ? _supportedTypes.first : settings.type;
    _apiKeyController.text = settings.apiKey;
    _indexers = List<IndexerEntryDto>.from(settings.indexers);
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
      showToast(_apiMessage(error, fallback: '保存索引器配置失败'));
    }
  }

  Future<void> _createIndexer() async {
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder:
          (dialogContext) => _IndexerEntryDialog(
            title: '新增索引器',
            downloadClients: _downloadClients,
          ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _indexers = List<IndexerEntryDto>.from(_indexers)..add(result);
    });
  }

  Future<void> _editIndexer(int index) async {
    final result = await showDialog<IndexerEntryDto>(
      context: context,
      builder:
          (dialogContext) => _IndexerEntryDialog(
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
    });
  }

  void _deleteIndexer(int index) {
    setState(() {
      _indexers = List<IndexerEntryDto>.from(_indexers)..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const _SectionSkeleton(lineCount: 5);
    }

    if (_errorMessage != null) {
      return _SectionErrorState(
        title: '索引器配置加载失败',
        message: _errorMessage!,
        onRetry: _loadTabData,
      );
    }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'API 密钥 (Key)',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            AppIconButton(
              tooltip: _obscureApiKey ? '显示 API 密钥' : '隐藏 API 密钥',
              onPressed:
                  () => setState(() {
                    _obscureApiKey = !_obscureApiKey;
                  }),
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: context.appComponentTokens.iconSizeSm,
                color: context.appTextPalette.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.md),
        AppTextField(
          controller: _apiKeyController,
          hintText: '请输入 Jackett API Key',
          obscureText: _obscureApiKey,
        ),
        SizedBox(height: context.appSpacing.sm),
        Text(
          '该密钥用于与 Jackett 后端进行身份验证',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                '索引器列表 (Indexers)',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            AppButton(
              key: const Key('configuration-indexer-create-button'),
              onPressed: _downloadClients.isEmpty ? null : _createIndexer,
              icon: const Icon(Icons.add_rounded),
              label: '添加',
              variant: AppButtonVariant.primary,
            ),
          ],
        ),
        if (_downloadClients.isEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
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
        SizedBox(height: context.appSpacing.md),
        _IndexerSearchField(controller: _searchController),
        SizedBox(height: context.appSpacing.lg),
        if (filteredIndexers.isEmpty)
          _IndexerEmptyState(message: query.isEmpty ? '还没有配置索引站' : '没有匹配的索引站')
        else
          _LineSection(
            children: filteredIndexers
                .map((item) {
                  final actualIndex = _indexers.indexOf(item);
                  return _IndexerEntryCard(
                    entry: item,
                    index: actualIndex,
                    onEdit: () => _editIndexer(actualIndex),
                    onDelete: () => _deleteIndexer(actualIndex),
                  );
                })
                .toList(growable: false),
          ),
        SizedBox(height: context.appSpacing.xl),
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
    final colors = context.appColors;

    return Container(
      key: Key('indexer-entry-card-$index'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          IndexerSourceAvatar(kind: entry.kind),
          SizedBox(width: context.appSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s18,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: context.appSpacing.sm),
                    IndexerKindBadge(kind: entry.kind),
                  ],
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  entry.url,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  '下载器: ${entry.downloadClientName}',
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
          SizedBox(width: context.appSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IndexerActionButton(
                key: Key('indexer-entry-edit-$index'),
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              SizedBox(width: context.appSpacing.sm),
              _IndexerActionButton(
                key: Key('indexer-entry-delete-$index'),
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadClientDialog extends StatefulWidget {
  const _DownloadClientDialog({
    required this.libraries,
    required this.title,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final String title;
  final DownloadClientDto? initialClient;

  @override
  State<_DownloadClientDialog> createState() => _DownloadClientDialogState();
}

class _DownloadClientDialogState extends State<_DownloadClientDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _clientSavePathController;
  late final TextEditingController _localRootPathController;
  int? _selectedLibraryId;

  bool get _isEditing => widget.initialClient != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClient;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _baseUrlController = TextEditingController(text: initial?.baseUrl ?? '');
    _usernameController = TextEditingController(text: initial?.username ?? '');
    _passwordController = TextEditingController();
    _clientSavePathController = TextEditingController(
      text: initial?.clientSavePath ?? '',
    );
    _localRootPathController = TextEditingController(
      text: initial?.localRootPath ?? '',
    );
    _selectedLibraryId = initial?.mediaLibraryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _clientSavePathController.dispose();
    _localRootPathController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      baseUrlController: _baseUrlController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      clientSavePathController: _clientSavePathController,
      localRootPathController: _localRootPathController,
      mediaLibraryId: _selectedLibraryId,
    );

    if (_isEditing) {
      Navigator.of(context).pop(value.toUpdatePayload());
      return;
    }

    Navigator.of(context).pop(value.toCreatePayload());
  }

  @override
  Widget build(BuildContext context) {
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
                baseUrlController: _baseUrlController,
                usernameController: _usernameController,
                passwordController: _passwordController,
                clientSavePathController: _clientSavePathController,
                localRootPathController: _localRootPathController,
                libraries: widget.libraries,
                selectedLibraryId: _selectedLibraryId,
                onLibraryChanged:
                    (value) => setState(() {
                      _selectedLibraryId = value;
                    }),
                isEditing: _isEditing,
                credentialsLayout: DownloadClientCredentialsLayout.horizontal,
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
                      onPressed: _submit,
                      label: '保存',
                      variant: AppButtonVariant.primary,
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
}

class _IndexerEntryDialog extends StatefulWidget {
  const _IndexerEntryDialog({
    required this.title,
    required this.downloadClients,
    this.initialEntry,
  });

  final String title;
  final List<DownloadClientDto> downloadClients;
  final IndexerEntryDto? initialEntry;

  @override
  State<_IndexerEntryDialog> createState() => _IndexerEntryDialogState();
}

class _IndexerEntryDialogState extends State<_IndexerEntryDialog> {
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

class _IndexerSearchField extends StatelessWidget {
  const _IndexerSearchField({required this.controller});

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

class _IndexerActionButton extends StatefulWidget {
  const _IndexerActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_IndexerActionButton> createState() => _IndexerActionButtonState();
}

class _IndexerActionButtonState extends State<_IndexerActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final layoutTokens = context.appLayoutTokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: layoutTokens.inlineActionButtonSize,
          height: layoutTokens.inlineActionButtonSize,
          decoration: BoxDecoration(
            color:
                _hovered ? context.appColors.surfaceMuted : Colors.transparent,
            borderRadius: context.appRadius.smBorder,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.secondary,
          ),
        ),
      ),
    );
  }
}

class _IndexerEmptyState extends StatelessWidget {
  const _IndexerEmptyState({required this.message});

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

class _DialogFieldLabel extends StatelessWidget {
  const _DialogFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children
          .map(
            (child) => Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.sm),
              child: child,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xxxl),
      alignment: Alignment.center,
      color: context.appColors.surfaceMuted,
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

class _SectionErrorState extends StatelessWidget {
  const _SectionErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.md),
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppButton(
          onPressed: () => onRetry(),
          icon: const Icon(Icons.refresh_rounded),
          label: '重试',
        ),
      ],
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(lineCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.smBorder,
            ),
          ),
        );
      }),
    );
  }
}

String _formatUpdatedAt(DateTime? value) {
  if (value == null) {
    return '未知';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

String _formatAccountDate(DateTime? value) {
  if (value == null) {
    return '未知';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}

String _formatLicenseValidUntil(MetadataProviderLicenseStatusDto? status) {
  if (status == null) {
    return '未提供';
  }
  final unixSeconds = status.licenseValidUntil;
  if (unixSeconds == null) {
    return status.active ? '永久有效' : '未提供';
  }
  final value = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  );
  return '有效至 ${DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal())}';
}

bool _isUnixSecondsExpired(int? unixSeconds) {
  if (unixSeconds == null) {
    return false;
  }
  final value = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  );
  return value.isBefore(DateTime.now().toUtc());
}

String _diagnosticValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '未提供';
  }
  return trimmed;
}

String _apiMessage(Object error, {required String fallback}) {
  return apiErrorMessage(error, fallback: fallback);
}

List<String> _parseCollectionNumberFeaturesInput(String rawValue) {
  return rawValue
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
