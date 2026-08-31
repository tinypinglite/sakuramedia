import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_info_pill.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

class DownloadClientsSection extends ConsumerStatefulWidget {
  const DownloadClientsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DownloadClientsSection> createState() =>
      _DownloadClientsSectionState();
}

class _DownloadClientsSectionState
    extends ConsumerState<DownloadClientsSection> {
  Future<void> _createClient(
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    final payload = await showDialog<CreateDownloadClientPayload>(
      context: context,
      builder: (_) => DownloadClientDialog(
        libraries: libraries,
        providers: providers,
        title: '添加下载器',
      ),
    );
    if (!mounted || payload == null) return;
    try {
      await ref.read(downloadClientsProvider.notifier).create(payload);
      showToast('下载器已创建');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建下载器失败'));
    }
  }

  Future<void> _editClient(
    DownloadClientDto client,
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    final payload = await showDialog<UpdateDownloadClientPayload>(
      context: context,
      builder: (_) => DownloadClientDialog(
        libraries: libraries,
        providers: providers,
        title: '编辑下载器',
        initialClient: client,
      ),
    );
    if (!mounted || payload == null) return;
    try {
      await ref
          .read(downloadClientsProvider.notifier)
          .updateClient(clientId: client.id, payload: payload);
      showToast('下载器已更新');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '更新下载器失败'));
    }
  }

  Future<void> _deleteClient(DownloadClientDto client) async {
    await showAppConfigDeleteConfirm(
      context: context,
      title: '删除下载器',
      message: '确认删除下载器“${client.name}”？该操作不会删除下载任务。',
      onDelete: () =>
          ref.read(downloadClientsProvider.notifier).delete(client.id),
      successToast: '下载器已删除',
      failureFallback: '删除下载器失败',
    );
  }

  List<MediaLibraryDto> _librariesForEdit(
    DownloadClientDto client,
    List<MediaLibraryDto> downloadableLibraries,
    Map<int, MediaLibraryDto> librariesById,
  ) {
    if (downloadableLibraries.any(
      (library) => library.id == client.libraryId,
    )) {
      return downloadableLibraries;
    }
    final currentLibrary = librariesById[client.libraryId];
    if (currentLibrary == null) return downloadableLibraries;
    return <MediaLibraryDto>[currentLibrary, ...downloadableLibraries];
  }

  Future<void> _refresh() {
    return Future.wait<void>([
      ref.read(downloadClientsProvider.notifier).reload(),
      ref.read(mediaLibrariesProvider.notifier).reload(),
      ref.read(mediaProviderCatalogProvider.notifier).reload(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final providersAsync = ref.watch(mediaProviderCatalogProvider);
    if (clientsAsync.isLoading ||
        librariesAsync.isLoading ||
        providersAsync.isLoading) {
      return const AppSectionSkeleton(lineCount: 4);
    }

    final error = clientsAsync.error ?? librariesAsync.error;
    final providerCatalogError = providersAsync.error;
    if (error != null) {
      return AppSectionError(
        title: '下载器配置加载失败',
        message: apiErrorMessage(error, fallback: '下载器配置加载失败，请稍后重试。'),
        onRetry: () async {
          await Future.wait<void>([
            ref.read(downloadClientsProvider.notifier).reload(),
            ref.read(mediaLibrariesProvider.notifier).reload(),
            ref.read(mediaProviderCatalogProvider.notifier).reload(),
          ]);
        },
      );
    }

    final clients = clientsAsync.value ?? const <DownloadClientDto>[];
    final allLibraries = librariesAsync.value ?? const <MediaLibraryDto>[];
    final providers = providersAsync.value ?? const <MediaProviderDto>[];
    final providersByKey = <String, MediaProviderDto>{
      for (final provider in providers) provider.providerKey: provider,
    };
    final downloadableLibraries = allLibraries
        .where(
          (library) =>
              providersByKey[library.providerKey]?.supportsDownloads ?? false,
        )
        .toList(growable: false);
    final librariesById = <int, MediaLibraryDto>{
      for (final library in allLibraries) library.id: library,
    };
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (providerCatalogError != null)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.lg),
            child: Text(
              'Provider 目录暂不可用，已有下载器仍可管理；恢复插件目录后才能新建或编辑 Provider 配置。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          )
        else if (downloadableLibraries.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.lg),
            child: Text(
              '当前没有支持下载的媒体库，请先配置可下载的媒体库 Provider。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ).copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (clients.isEmpty)
          const AppEmptyState(message: '还没有下载器配置')
        else
          AppSettingsGroup(
            children: [
              for (final client in clients)
                DownloadClientCard(
                  client: client,
                  mediaLibrary: librariesById[client.libraryId],
                  provider:
                      providersByKey[librariesById[client.libraryId]
                          ?.providerKey],
                  onEdit: () => _editClient(
                    client,
                    _librariesForEdit(
                      client,
                      downloadableLibraries,
                      librariesById,
                    ),
                    providers,
                  ),
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
              onTap: downloadableLibraries.isEmpty
                  ? null
                  : () => _createClient(downloadableLibraries, providers),
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
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final MediaProviderDto? provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final providerName =
        provider?.displayName ?? mediaLibrary?.providerKey ?? '未知 Provider';
    final libraryName = mediaLibrary?.name ?? '未匹配 (${client.libraryId})';
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
                AppInfoPill(label: 'Provider', value: providerName),
                AppInfoPill(label: '媒体库', value: libraryName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadClientDialog extends ConsumerStatefulWidget {
  const DownloadClientDialog({
    super.key,
    required this.libraries,
    required this.providers,
    required this.title,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  final String title;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<DownloadClientDialog> createState() =>
      _DownloadClientDialogState();
}

class _DownloadClientDialogState extends ConsumerState<DownloadClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late ProviderConfigFormController _providerConfigController;
  int? _selectedLibraryId;
  bool _isTesting = false;
  DownloadClientDiagnosticReportDto? _diagnosticReport;

  bool get _isEditing => widget.initialClient != null;

  MediaProviderDto? _providerForLibrary(int? libraryId) {
    if (libraryId == null) return null;
    final library = widget.libraries.cast<MediaLibraryDto?>().firstWhere(
      (item) => item?.id == libraryId,
      orElse: () => null,
    );
    if (library == null) return null;
    for (final provider in widget.providers) {
      if (provider.providerKey == library.providerKey) return provider;
    }
    return null;
  }

  ProviderConfigFormController _newConfigController(
    int? libraryId,
    Map<String, dynamic> initialConfig,
  ) {
    final fields =
        _providerForLibrary(libraryId)?.downloadConfigFields ??
        const <ProviderConfigFieldDto>[];
    return ProviderConfigFormController(
      fields: fields,
      initialConfig: initialConfig,
    );
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClient;
    _selectedLibraryId =
        initial?.libraryId ??
        (widget.libraries.isEmpty ? null : widget.libraries.first.id);
    _nameController = TextEditingController(text: initial?.name ?? '');
    _providerConfigController = _newConfigController(
      _selectedLibraryId,
      initial?.providerConfig ?? const <String, dynamic>{},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerConfigController.dispose();
    super.dispose();
  }

  void _selectLibrary(int? value) {
    if (value == _selectedLibraryId) return;
    final old = _providerConfigController;
    final next = _newConfigController(value, const <String, dynamic>{});
    setState(() {
      _selectedLibraryId = value;
      _providerConfigController = next;
    });
    old.dispose();
  }

  void _submit() {
    if (_isTesting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
    Navigator.of(
      context,
    ).pop(_isEditing ? value.toUpdatePayload() : value.toCreatePayload());
  }

  Future<void> _testClient() async {
    if (_isTesting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
    final libraryId = value.libraryId;
    if (libraryId == null) return;
    setState(() {
      _isTesting = true;
      _diagnosticReport = null;
    });
    try {
      final report = await ref.read(downloadClientsApiProvider).testClient(
        DownloadClientTestPayload(
          libraryId: libraryId,
          providerConfig: value.providerConfig,
          clientId: widget.initialClient?.id,
        ),
      );
      if (!mounted) return;
      setState(() => _diagnosticReport = report);
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '下载器测试失败'));
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
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
                libraries: widget.libraries,
                selectedLibraryId: _selectedLibraryId,
                onLibraryChanged: _selectLibrary,
                providerConfigController: _providerConfigController,
                isEditing: _isEditing,
                enabled: !_isTesting,
              ),
              if (_diagnosticReport != null) ...[
                SizedBox(height: spacing.lg),
                DownloadClientDiagnosticResultView(report: _diagnosticReport!),
              ],
              SizedBox(height: spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: _isTesting
                          ? null
                          : () => Navigator.of(context).pop(),
                      label: '取消',
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      onPressed: _isTesting ? null : _submit,
                      label: '保存',
                      variant: AppButtonVariant.primary,
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      key: const Key('download-client-test-button'),
                      onPressed: _isTesting ? null : _testClient,
                      label: '测试配置',
                      icon: const Icon(Icons.rule_rounded),
                      size: AppButtonSize.small,
                      isLoading: _isTesting,
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
