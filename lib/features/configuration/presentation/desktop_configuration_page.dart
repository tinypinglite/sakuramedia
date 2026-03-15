import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
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
    _tabController = TabController(length: 3, vsync: this)
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
              Tab(key: Key('configuration-tab-basic'), text: '基础信息'),
              Tab(key: Key('configuration-tab-downloads'), text: '下载器'),
              Tab(key: Key('configuration-tab-indexers'), text: '索引器'),
            ],
          ),
          SizedBox(height: context.appSpacing.xl),
          IndexedStack(
            index: _selectedIndex,
            children: [
              _BasicInformationTab(
                active: _selectedIndex == 0,
                onLibrariesChanged: _handleMediaLibrariesChanged,
              ),
              _DownloadClientsTab(
                active: _selectedIndex == 1,
                librariesRevision: _mediaLibrariesRevision,
              ),
              _IndexerSettingsTab(active: _selectedIndex == 2),
            ],
          ),
        ],
      ),
    );
  }
}

class _BasicInformationTab extends StatefulWidget {
  const _BasicInformationTab({
    required this.active,
    required this.onLibrariesChanged,
  });

  final bool active;
  final VoidCallback onLibrariesChanged;

  @override
  State<_BasicInformationTab> createState() => _BasicInformationTabState();
}

class _BasicInformationTabState extends State<_BasicInformationTab> {
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
  void didUpdateWidget(covariant _BasicInformationTab oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaLibrariesSection(context),
        SizedBox(height: context.appSpacing.xl),
        const _AccountSecuritySection(),
      ],
    );
  }

  Widget _buildMediaLibrariesSection(BuildContext context) {
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
                style: Theme.of(context).textTheme.bodyMedium,
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
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
                  ),
                )
                .toList(growable: false),
          ),
      ],
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
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      final username = (await accountApi.getAccount()).username.trim();

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

    return AppContentCard(
      title: '账号安全',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: Theme.of(context).textTheme.titleSmall,
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '修改密码后将立即退出当前登录，需要使用新密码重新登录。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textMuted,
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
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除下载器',
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
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
    final textTheme = Theme.of(context).textTheme;
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
                    Text(client.name, style: textTheme.titleSmall),
                    SizedBox(height: context.appSpacing.xs),
                    Text(client.baseUrl, style: textTheme.bodyMedium),
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

class _MediaLibraryCard extends StatelessWidget {
  const _MediaLibraryCard({required this.library, required this.onEdit});

  final MediaLibraryDto library;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: Key('media-library-card-${library.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
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
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  library.rootPath,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  'ID: ${library.id}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  '更新时间: ${_formatUpdatedAt(library.updatedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: context.appSpacing.md),
          _IndexerActionButton(
            key: Key('media-library-edit-${library.id}'),
            icon: Icons.edit_outlined,
            onTap: onEdit,
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

    final name = _nameController.text.trim();
    final rootPath = _rootPathController.text.trim();
    if (_isEditing) {
      Navigator.of(
        context,
      ).pop(UpdateMediaLibraryPayload(name: name, rootPath: rootPath));
      return;
    }

    Navigator.of(
      context,
    ).pop(CreateMediaLibraryPayload(name: name, rootPath: rootPath));
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppDesktopDialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      width: 520,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: spacing.xl),
            const _DialogFieldLabel(label: '名称'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('media-library-name-field'),
              controller: _nameController,
              hintText: '例如: Main Library',
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty ? '请输入媒体库名称' : null,
            ),
            SizedBox(height: spacing.lg),
            const _DialogFieldLabel(label: '根路径'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('media-library-root-path-field'),
              controller: _rootPathController,
              hintText: '填映射到容器内的路径，例如: /mnt/medialibray1',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入媒体库根路径';
                }
                if (!_isAbsolutePath(value.trim())) {
                  return '请输入路径';
                }
                return null;
              },
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
    final duplicateNames = _findDuplicateIndexerNames(_indexers);
    if (duplicateNames.isNotEmpty) {
      showToast('索引器名称重复: ${duplicateNames.first}');
      return;
    }
    for (final item in _indexers) {
      if (!_isValidHttpUrl(item.url)) {
        showToast('索引器 URL 必须是合法的 http/https 地址');
        return;
      }
      if (!_isSupportedIndexerKind(item.kind)) {
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
                style: Theme.of(context).textTheme.bodyMedium,
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
                color: context.appColors.textMuted,
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
        ),
        SizedBox(height: context.appSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                '索引器列表 (Indexers)',
                style: Theme.of(context).textTheme.bodyMedium,
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
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
          _IndexerSourceAvatar(kind: entry.kind),
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
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    SizedBox(width: context.appSpacing.sm),
                    _IndexerKindBadge(kind: entry.kind),
                  ],
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  entry.url,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  '下载器: ${entry.downloadClientName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
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

    if (_isEditing) {
      Navigator.of(context).pop(
        UpdateDownloadClientPayload(
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          username: _usernameController.text.trim(),
          password:
              _passwordController.text.trim().isEmpty
                  ? null
                  : _passwordController.text.trim(),
          clientSavePath: _clientSavePathController.text.trim(),
          localRootPath: _localRootPathController.text.trim(),
          mediaLibraryId: _selectedLibraryId,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      CreateDownloadClientPayload(
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        clientSavePath: _clientSavePathController.text.trim(),
        localRootPath: _localRootPathController.text.trim(),
        mediaLibraryId: _selectedLibraryId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppDesktopDialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: spacing.xl),
              AppTextField(
                fieldKey: const Key('download-client-name-field'),
                controller: _nameController,
                label: '名称',
                hintText: '给下载器起个名字，例如：pt 专属',
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '请输入下载器名称'
                            : null,
              ),
              SizedBox(height: context.appSpacing.lg),
              AppTextField(
                fieldKey: const Key('download-client-base-url-field'),
                controller: _baseUrlController,
                label: '服务地址',
                hintText: '填写完整内网地址，例如：http://192.168.1.2:8080',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入服务地址';
                  }
                  if (!_isValidHttpUrl(value.trim())) {
                    return '请输入合法的 http/https 地址';
                  }
                  return null;
                },
              ),
              SizedBox(height: context.appSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      fieldKey: const Key('download-client-username-field'),
                      controller: _usernameController,
                      label: '用户名',
                      hintText: '输入用于登录下载器的用户名',
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? '请输入用户名'
                                  : null,
                    ),
                  ),
                  SizedBox(width: context.appSpacing.md),
                  Expanded(
                    child: AppTextField(
                      fieldKey: const Key('download-client-password-field'),
                      controller: _passwordController,
                      label: '密码',
                      hintText: '输入用于登录下载器的密码',
                      helperText: _isEditing ? '留空则保持原密码不变' : null,
                      obscureText: true,
                      validator: (value) {
                        if (_isEditing) {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.lg),
              AppTextField(
                fieldKey: const Key('download-client-client-save-path-field'),
                controller: _clientSavePathController,
                label: 'qBittorrent保存路径',
                hintText: '填写 qBittorrent 容器内使用的路径，例如：/downloads',
                helperText: 'qBittorrent 实际保存文件时使用的路径',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入qBittorrent保存路径';
                  }
                  if (!_isAbsolutePath(value.trim())) {
                    return '请输入路径';
                  }
                  return null;
                },
              ),
              SizedBox(height: context.appSpacing.lg),
              AppTextField(
                fieldKey: const Key('download-client-local-root-path-field'),
                controller: _localRootPathController,
                label: '本地访问路径',
                hintText: '填写 SakuraMediaBE 中的实际下载绝对路径，例如:/mnt/downloads',
                helperText: '注意确保和 qBittorrent 的下载路径在宿主机上是同一个路径.',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入本地访问路径';
                  }
                  if (!_isAbsolutePath(value.trim())) {
                    return '请输入路径';
                  }
                  return null;
                },
              ),
              SizedBox(height: context.appSpacing.lg),
              AppSelectField<int>(
                key: const Key('download-client-media-library-field'),
                value: _selectedLibraryId,
                items: widget.libraries
                    .map(
                      (library) => DropdownMenuItem<int>(
                        value: library.id,
                        child: Text(library.name),
                      ),
                    )
                    .toList(growable: false),
                label: '目标媒体库',
                onChanged:
                    widget.libraries.isEmpty
                        ? null
                        : (value) => setState(() {
                          _selectedLibraryId = value;
                        }),
                validator: (value) => value == null ? '请选择目标媒体库' : null,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      width: 520,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: spacing.xl),
            _DialogFieldLabel(label: '名称 (NAME)'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('indexer-entry-name-field'),
              controller: _nameController,
              hintText: '例如: 馒头',
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty ? '请输入索引器名称' : null,
            ),
            SizedBox(height: spacing.lg),
            _DialogFieldLabel(label: '资源地址 (URL)'),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('indexer-entry-url-field'),
              controller: _urlController,
              hintText: '填写完整的 torznab 地址',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入索引器 URL';
                }
                if (!_isValidHttpUrl(value.trim())) {
                  return '请输入合法的 http/https 地址';
                }
                return null;
              },
            ),
            SizedBox(height: spacing.lg),
            _DialogFieldLabel(label: '类别 (KIND)'),
            SizedBox(height: spacing.sm),
            Row(
              key: const Key('indexer-entry-kind-field'),
              children: [
                Expanded(
                  child: _KindOptionButton(
                    label: 'PT (私有)',
                    selected: _kind == 'pt',
                    onTap: () => setState(() => _kind = 'pt'),
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                Expanded(
                  child: _KindOptionButton(
                    label: 'BT (公网)',
                    selected: _kind == 'bt',
                    onTap: () => setState(() => _kind = 'bt'),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),
            AppSelectField<int>(
              key: const Key('indexer-entry-download-client-field'),
              value: _selectedDownloadClientId,
              items: widget.downloadClients
                  .map(
                    (client) => DropdownMenuItem<int>(
                      value: client.id,
                      child: Text(client.name),
                    ),
                  )
                  .toList(growable: false),
              label: '绑定下载器',
              placeholder:
                  widget.downloadClients.isEmpty
                      ? '请先在下载器 Tab 创建下载器'
                      : '请选择下载器',
              onChanged:
                  widget.downloadClients.isEmpty
                      ? null
                      : (value) => setState(() {
                        _selectedDownloadClientId = value;
                      }),
              validator: (value) => value == null ? '请选择下载器' : null,
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
    final colors = context.appColors;

    return AppTextField(
      controller: controller,
      hintText: '搜索已添加的索引器...',
      prefix: Icon(
        Icons.search_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: colors.textMuted,
      ),
      onChanged: (_) {},
      isDense: false,
    );
  }
}

class _IndexerSourceAvatar extends StatelessWidget {
  const _IndexerSourceAvatar({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        kind == 'bt' ? const Color(0xFFEAF3FF) : const Color(0xFFFFF1EF);
    final foregroundColor =
        kind == 'bt' ? const Color(0xFF1677FF) : const Color(0xFFF04438);
    final icon =
        kind == 'bt' ? Icons.language_rounded : Icons.cloud_download_outlined;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.mdBorder,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeLg,
        color: foregroundColor,
      ),
    );
  }
}

class _IndexerKindBadge extends StatelessWidget {
  const _IndexerKindBadge({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final isBt = kind == 'bt';
    final backgroundColor =
        isBt ? const Color(0xFFEAF3FF) : const Color(0xFFFFF1EF);
    final foregroundColor =
        isBt ? const Color(0xFF1677FF) : const Color(0xFFF04438);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Text(
        isBt ? 'BT' : 'PT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                _hovered ? context.appColors.surfaceMuted : Colors.transparent,
            borderRadius: context.appRadius.smBorder,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appColors.textSecondary,
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
            color: context.appColors.textMuted,
          ),
          SizedBox(height: context.appSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
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
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.appColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _KindOptionButton extends StatelessWidget {
  const _KindOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        selected ? const Color(0xFFEAF3FF) : context.appColors.surfaceMuted;
    final borderColor =
        selected ? const Color(0xFF1677FF) : context.appColors.borderSubtle;
    final foregroundColor =
        selected ? const Color(0xFF1677FF) : context.appColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: context.appRadius.mdBorder,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
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
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: context.appSpacing.md),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
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

String _apiMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    return error.error?.message ?? error.message;
  }
  return fallback;
}

bool _isValidHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool _isAbsolutePath(String value) {
  if (value.startsWith('/')) {
    return true;
  }
  return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
}

bool _isSupportedIndexerKind(String value) {
  return value == 'pt' || value == 'bt';
}

Set<String> _findDuplicateIndexerNames(List<IndexerEntryDto> items) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final item in items) {
    final normalized = item.name.trim();
    if (normalized.isEmpty) {
      continue;
    }
    if (!seen.add(normalized)) {
      duplicates.add(normalized);
    }
  }
  return duplicates;
}
