import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_form.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_settings_group.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/forms/app_info_pill.dart';

class DownloadClientsSection extends StatefulWidget {
  const DownloadClientsSection({
    super.key,
    required this.active,
    required this.librariesRevision,
  });

  final bool active;
  final int librariesRevision;

  @override
  State<DownloadClientsSection> createState() => _DownloadClientsSectionState();
}

class _DownloadClientsSectionState extends State<DownloadClientsSection> {
  bool _initialized = false;
  bool _isLoading = false;
  bool _needsReload = false;
  String? _errorMessage;
  List<DownloadClientDto> _clients = const <DownloadClientDto>[];
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];

  @override
  void didUpdateWidget(covariant DownloadClientsSection oldWidget) {
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
        _errorMessage = apiErrorMessage(error, fallback: '下载器配置加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _createClient() async {
    final api = context.read<DownloadClientsApi>();
    final payload = await showDialog<CreateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) =>
              DownloadClientDialog(libraries: _libraries, title: '添加下载器'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await api.createClient(payload);
      showToast('下载器已创建');
      await _loadData();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建下载器失败'));
    }
  }

  Future<void> _editClient(DownloadClientDto client) async {
    final api = context.read<DownloadClientsApi>();
    final payload = await showDialog<UpdateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) => DownloadClientDialog(
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
      showToast(apiErrorMessage(error, fallback: '更新下载器失败'));
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
      showToast(apiErrorMessage(error, fallback: '删除下载器失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const AppSectionSkeleton(lineCount: 4);
    }

    if (_errorMessage != null) {
      return AppSectionError(
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
                DownloadClientCard(
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

class DownloadClientCard extends StatelessWidget {
  const DownloadClientCard({
    super.key,
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
              AppInlineActionButton(
                key: Key('download-client-edit-${client.id}'),
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              SizedBox(width: spacing.xs),
              AppInlineActionButton(
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
                AppInfoPill(label: '用户名', value: client.username),
                AppInfoPill(
                  label: '媒体库',
                  value:
                      mediaLibrary == null
                          ? '未匹配 (${client.mediaLibraryId})'
                          : mediaLibrary!.name,
                ),
                AppInfoPill(
                  label: 'qBittorrent保存路径',
                  value: client.clientSavePath,
                ),
                AppInfoPill(label: '本地访问路径', value: client.localRootPath),
                AppInfoPill(
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

class DownloadClientDialog extends StatefulWidget {
  const DownloadClientDialog({
    super.key,
    required this.libraries,
    required this.title,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final String title;
  final DownloadClientDto? initialClient;

  @override
  State<DownloadClientDialog> createState() => _DownloadClientDialogState();
}

class _DownloadClientDialogState extends State<DownloadClientDialog> {
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
