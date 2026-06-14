import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
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
import 'package:sakuramedia/features/configuration/presentation/desktop_llm_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/indexer_entry_form.dart';
import 'package:sakuramedia/features/configuration/presentation/media_library_form.dart';
import 'package:sakuramedia/features/media/presentation/desktop_media_maintenance_page.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_settings_group.dart';
import 'package:sakuramedia/widgets/app_shell/app_settings_rail.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class DesktopConfigurationPage extends StatefulWidget {
  const DesktopConfigurationPage({super.key});

  @override
  State<DesktopConfigurationPage> createState() =>
      _DesktopConfigurationPageState();
}

class _DesktopConfigurationPageState extends State<DesktopConfigurationPage> {
  int _selectedIndex = 0;
  int _mediaLibrariesRevision = 0;

  // 顺序即右侧 IndexedStack 的索引；itemKey 沿用原 tab key，保持深链/测试兼容。
  static const List<_ConfigurationCategory> _categories = [
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-media-libraries'),
      label: '媒体库',
      icon: Icons.folder_open_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-collection-features'),
      label: '合集特征',
      icon: Icons.tag_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-llm'),
      label: 'LLM 配置',
      icon: Icons.auto_awesome_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-account-security'),
      label: '账号安全',
      icon: Icons.shield_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-downloads'),
      label: '下载器',
      icon: Icons.download_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-indexers'),
      label: '索引器',
      icon: Icons.travel_explore_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-playlists'),
      label: '播放列表',
      icon: Icons.playlist_play_outlined,
    ),
    _ConfigurationCategory(
      itemKey: Key('configuration-tab-media-maintenance'),
      label: '媒体维护',
      icon: Icons.cleaning_services_outlined,
    ),
  ];

  void _select(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleMediaLibrariesChanged() {
    setState(() {
      _mediaLibrariesRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      key: const Key('configuration-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsRail(
          selectedIndex: _selectedIndex,
          onSelected: _select,
          items: [
            for (final category in _categories)
              AppSettingsRailItem(
                itemKey: category.itemKey,
                label: category.label,
                icon: category.icon,
              ),
          ],
        ),
        SizedBox(width: spacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: spacing.lg),
                child: Text(
                  _categories[_selectedIndex].label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s20,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  sizing: StackFit.expand,
                  children: [
                    _ConfigurationTabScrollView(
                      child: _MediaLibrariesTab(
                        active: _selectedIndex == 0,
                        onLibrariesChanged: _handleMediaLibrariesChanged,
                      ),
                    ),
                    _ConfigurationTabScrollView(
                      child: _CollectionNumberFeaturesTab(
                        active: _selectedIndex == 1,
                      ),
                    ),
                    _ConfigurationTabScrollView(
                      child: DesktopLlmSettingsSection(
                        active: _selectedIndex == 2,
                      ),
                    ),
                    const _ConfigurationTabScrollView(
                      child: _AccountSecuritySection(),
                    ),
                    _ConfigurationTabScrollView(
                      child: _DownloadClientsTab(
                        active: _selectedIndex == 4,
                        librariesRevision: _mediaLibrariesRevision,
                      ),
                    ),
                    _ConfigurationTabScrollView(
                      child: _IndexerSettingsTab(active: _selectedIndex == 5),
                    ),
                    _ConfigurationTabScrollView(
                      child: _PlaylistsTab(active: _selectedIndex == 6),
                    ),
                    // 媒体维护页自带滚动控制器（无限滚动分页），直接铺满区域，
                    // 不再额外包一层滚动视图。
                    DesktopMediaMaintenancePage(active: _selectedIndex == 7),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 系统设置左侧分类项描述。
class _ConfigurationCategory {
  const _ConfigurationCategory({
    required this.itemKey,
    required this.label,
    required this.icon,
  });

  final Key itemKey;
  final String label;
  final IconData icon;
}

/// 系统设置各 tab 的统一滚动容器：tab 栏固定，内容区各自滚动。
class _ConfigurationTabScrollView extends StatelessWidget {
  const _ConfigurationTabScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xl),
        child: child,
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除媒体库',
      message: '确认删除媒体库“${library.name}”？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
    );

    if (!mounted || !confirmed) {
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

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '媒体库用于维护本地媒体存储根路径，下载器等模块会依赖这里的路径配置。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.lg),
        if (_libraries.isEmpty)
          const AppEmptyState(message: '还没有媒体库')
        else
          AppSettingsGroup(
            // 分隔线缩到主标题起点（行左边距 + 图标盒 + 间隙）。
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in _libraries)
                AppSettingCell(
                  key: Key('media-library-card-${library.id}'),
                  icon: Icons.folder_open_outlined,
                  title: library.name,
                  subtitle: library.rootPath,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID ${library.id}',
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      _IndexerActionButton(
                        key: Key('media-library-edit-${library.id}'),
                        icon: Icons.edit_outlined,
                        onTap: () => _editLibrary(library),
                      ),
                      SizedBox(width: spacing.xs),
                      _IndexerActionButton(
                        key: Key('media-library-delete-${library.id}'),
                        icon: Icons.delete_outline,
                        onTap: () => _deleteLibrary(library),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-media-library-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: '新增媒体库',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createLibrary,
            ),
          ],
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
      await context.logOut();
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除下载器',
      message: '确认删除下载器“${client.name}”？该操作不会删除下载任务。',
      danger: true,
      confirmLabel: '删除',
    );

    if (!mounted || !confirmed) {
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

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_libraries.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.lg),
            child: Text(
              '当前没有可用媒体库，创建下载器前请先在后端配置媒体库。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ).copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_clients.isEmpty)
          const AppEmptyState(message: '还没有下载器配置')
        else
          AppSettingsGroup(
            children: [
              for (final client in _clients)
                _DownloadClientCard(
                  client: client,
                  mediaLibrary: librariesById[client.mediaLibraryId],
                  onEdit: () => _editClient(client),
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
              title: '新建下载器',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _libraries.isEmpty ? null : _createClient,
            ),
          ],
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
    final spacing = context.appSpacing;

    return Padding(
      key: Key('download-client-card-${client.id}'),
      padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSettingIconBox(icon: Icons.cloud_download_outlined),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      client.baseUrl,
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
              _IndexerActionButton(
                key: Key('download-client-edit-${client.id}'),
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              SizedBox(width: spacing.xs),
              _IndexerActionButton(
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
                _InfoPill(label: '用户名', value: client.username),
                _InfoPill(
                  label: '媒体库',
                  value:
                      mediaLibrary == null
                          ? '未匹配 (${client.mediaLibraryId})'
                          : mediaLibrary!.name,
                ),
                _InfoPill(
                  label: 'qBittorrent保存路径',
                  value: client.clientSavePath,
                ),
                _InfoPill(label: '本地访问路径', value: client.localRootPath),
                _InfoPill(
                  label: '密码',
                  value: client.hasPassword ? '已设置' : '未设置',
                ),
              ],
            ),
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

    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
    );
    if (!mounted || !confirmed) {
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

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_playlists.isEmpty)
          const AppEmptyState(message: '还没有自定义播放列表')
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final playlist in _playlists)
                AppSettingCell(
                  key: Key('playlist-card-${playlist.id}'),
                  icon: Icons.playlist_play_outlined,
                  title: playlist.name,
                  subtitle: _playlistSubtitle(playlist),
                  trailing: _playlistTrailing(context, playlist),
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-playlist-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: '新建播放列表',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createPlaylist,
            ),
          ],
        ),
      ],
    );
  }

  String _playlistSubtitle(PlaylistDto playlist) {
    final description = playlist.description.trim();
    if (description.isNotEmpty) {
      return '$description · ${playlist.movieCount} 部';
    }
    return '${playlist.movieCount} 部影片';
  }

  Widget? _playlistTrailing(BuildContext context, PlaylistDto playlist) {
    if (!playlist.isMutable && !playlist.isDeletable) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playlist.isMutable)
          _IndexerActionButton(
            key: Key('playlist-edit-${playlist.id}'),
            icon: Icons.edit_outlined,
            onTap: () => _editPlaylist(playlist),
          ),
        if (playlist.isMutable && playlist.isDeletable)
          SizedBox(width: context.appSpacing.xs),
        if (playlist.isDeletable)
          _IndexerActionButton(
            key: Key('playlist-delete-${playlist.id}'),
            icon: Icons.delete_outline,
            onTap: () => _deletePlaylist(playlist),
          ),
      ],
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
              AppTextField(
                controller: _apiKeyController,
                hintText: '请输入 Jackett API Key',
                obscureText: _obscureApiKey,
                suffix: AppIconButton(
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
                  ),
                ),
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
        _IndexerSearchField(controller: _searchController),
        SizedBox(height: spacing.md),
        if (filteredIndexers.isEmpty)
          _IndexerEmptyState(message: query.isEmpty ? '还没有配置索引站' : '没有匹配的索引站')
        else
          AppSettingsGroup(
            children: [
              for (final item in filteredIndexers)
                _IndexerEntryCard(
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

    return Padding(
      key: Key('indexer-entry-card-$index'),
      padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
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
          _IndexerActionButton(
            key: Key('indexer-entry-edit-$index'),
            icon: Icons.edit_outlined,
            onTap: onEdit,
          ),
          SizedBox(width: spacing.xs),
          _IndexerActionButton(
            key: Key('indexer-entry-delete-$index'),
            icon: Icons.delete_outline,
            onTap: onDelete,
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

String _formatAccountDate(DateTime? value) {
  if (value == null) {
    return '未知';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
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
