import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/download_client_probe_interactions.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_client_probe_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_info_pill.dart';

class DownloadClientsSection extends ConsumerStatefulWidget {
  const DownloadClientsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DownloadClientsSection> createState() =>
      _DownloadClientsSectionState();
}

class _DownloadClientsSectionState
    extends ConsumerState<DownloadClientsSection> {
  Future<void> _createClient() async {
    final libraries =
        ref.read(mediaLibrariesProvider).value ?? const <MediaLibraryDto>[];
    final payload = await showDialog<CreateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) =>
              DownloadClientDialog(libraries: libraries, title: '添加下载器'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await ref.read(downloadClientsProvider.notifier).create(payload);
      showToast('下载器已创建');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建下载器失败'));
    }
  }

  Future<void> _editClient(DownloadClientDto client) async {
    final libraries =
        ref.read(mediaLibrariesProvider).value ?? const <MediaLibraryDto>[];
    final payload = await showDialog<UpdateDownloadClientPayload>(
      context: context,
      builder:
          (dialogContext) => DownloadClientDialog(
            libraries: libraries,
            title: '编辑下载器',
            initialClient: client,
          ),
    );
    if (!mounted || payload == null) {
      return;
    }

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
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除下载器',
      message: '确认删除下载器“${client.name}”？该操作不会删除下载任务。',
      onDelete:
          () => ref.read(downloadClientsProvider.notifier).delete(client.id),
      successToast: '下载器已删除',
      failureFallback: '删除下载器失败',
    );
    if (!ok || !mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    if (clientsAsync.isLoading || librariesAsync.isLoading) {
      return const AppSectionSkeleton(lineCount: 4);
    }
    final error = clientsAsync.error ?? librariesAsync.error;
    if (error != null) {
      return AppSectionError(
        title: '下载器配置加载失败',
        message: apiErrorMessage(error, fallback: '下载器配置加载失败，请稍后重试。'),
        onRetry: () async {
          await Future.wait<void>([
            ref.read(downloadClientsProvider.notifier).reload(),
            ref.read(mediaLibrariesProvider.notifier).reload(),
          ]);
        },
      );
    }

    final clients = clientsAsync.value ?? const <DownloadClientDto>[];
    final libraries = librariesAsync.value ?? const <MediaLibraryDto>[];

    final librariesById = <int, MediaLibraryDto>{
      for (final library in libraries) library.id: library,
    };

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (libraries.isEmpty)
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
        if (clients.isEmpty)
          const AppEmptyState(message: '还没有下载器配置')
        else
          AppSettingsGroup(
            children: [
              for (final client in clients)
                DownloadClientCard(
                  client: client,
                  mediaLibrary: librariesById[client.mediaLibraryId],
                  onEdit: () => _editClient(client),
                  onDelete: () => _deleteClient(client),
                  runTest:
                      () => ref
                          .read(downloadClientsApiProvider)
                          .testClient(client.id),
                  runStorageTest:
                      client.isQbittorrent
                          ? () => ref
                              .read(downloadClientsApiProvider)
                              .storageTestClient(client.id)
                          : null,
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
              onTap: libraries.isEmpty ? null : _createClient,
            ),
          ],
        ),
      ],
    );
  }
}

class DownloadClientCard extends ConsumerStatefulWidget {
  const DownloadClientCard({
    super.key,
    required this.client,
    required this.mediaLibrary,
    required this.onEdit,
    required this.onDelete,
    required this.runTest,
    required this.runStorageTest,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<DownloadClientTestResultDto> Function() runTest;
  final Future<DownloadClientStorageTestResultDto> Function()? runStorageTest;

  @override
  ConsumerState<DownloadClientCard> createState() => _DownloadClientCardState();
}

class _DownloadClientCardState extends ConsumerState<DownloadClientCard> {
  final Object _probeScope = Object();

  @override
  void didUpdateWidget(covariant DownloadClientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 配置任何字段变了(后端会 bump updatedAt) → 老探针结果作废,回到未检测态。
    // 用 updatedAt 判定,才不会漏掉「只改了密码」的场景 —— DTO 里没有原文,
    // 但 updatedAt 会更新。
    if (oldWidget.client.id != widget.client.id ||
        oldWidget.client.updatedAt != widget.client.updatedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(downloadClientProbeProvider(_probeScope).notifier).reset();
      });
    }
  }

  Future<void> _handleConnectivityChipTap() {
    return handleProbeConnectivityTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: widget.runTest,
      openDialog: _openConnectivityDialog,
    );
  }

  Future<void> _handleStorageChipTap() {
    final runStorageTest = widget.runStorageTest;
    if (runStorageTest == null) return Future<void>.value();
    return handleProbeStorageTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: runStorageTest,
      openDialog: _openStorageDialog,
    );
  }

  Future<void> _openConnectivityDialog(
    DownloadClientTestResultDto result,
  ) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientTestResultDialog(
            initialResult: result,
            onRerun: widget.runTest,
            onResultChanged:
                ref
                    .read(downloadClientProbeProvider(_probeScope).notifier)
                    .applyConnectivityResult,
          ),
    );
  }

  Future<void> _openStorageDialog(
    DownloadClientStorageTestResultDto result,
  ) async {
    final runStorageTest = widget.runStorageTest;
    if (runStorageTest == null) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientStorageTestResultDialog(
            initialResult: result,
            clientBaseUrl: widget.client.baseUrl,
            onRerun: runStorageTest,
            onResultChanged:
                ref
                    .read(downloadClientProbeProvider(_probeScope).notifier)
                    .applyStorageResult,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final client = widget.client;
    final mediaLibrary = widget.mediaLibrary;
    final probe = ref.watch(downloadClientProbeProvider(_probeScope));
    final busy = probe.busy;

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
              AppSettingIconBox(
                icon:
                    client.isCloud115
                        ? Icons.cloud_outlined
                        : Icons.cloud_download_outlined,
              ),
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
                      client.isCloud115 ? '115 离线下载' : client.baseUrl,
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
              DownloadClientProbeStatusChip(
                key: Key('download-client-test-${client.id}'),
                label: '连通性',
                state: probe.connectivityChipState,
                detail: probe.connectivityChipDetail,
                tooltip: probe.connectivityTooltip,
                onTap: busy ? null : _handleConnectivityChipTap,
              ),
              if (client.isQbittorrent) ...[
                SizedBox(width: spacing.xs),
                DownloadClientProbeStatusChip(
                  key: Key('download-client-storage-test-${client.id}'),
                  label: '目录映射',
                  state: probe.storageChipState,
                  detail: probe.storageChipDetail,
                  tooltip: probe.storageTooltip,
                  onTap: busy ? null : _handleStorageChipTap,
                ),
              ],
              SizedBox(width: spacing.sm),
              AppInlineActionButton(
                key: Key('download-client-edit-${client.id}'),
                icon: Icons.edit_outlined,
                onTap: widget.onEdit,
              ),
              SizedBox(width: spacing.xs),
              AppInlineActionButton(
                key: Key('download-client-delete-${client.id}'),
                icon: Icons.delete_outline,
                onTap: widget.onDelete,
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
                AppInfoPill(label: '类型', value: client.kind.label),
                AppInfoPill(
                  label: '媒体库',
                  value:
                      mediaLibrary == null
                          ? '未匹配 (${client.mediaLibraryId})'
                          : mediaLibrary.name,
                ),
                if (client.isQbittorrent) ...[
                  AppInfoPill(label: '用户名', value: client.username),
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
    required this.title,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final String title;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<DownloadClientDialog> createState() =>
      _DownloadClientDialogState();
}

class _DownloadClientDialogState extends ConsumerState<DownloadClientDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _clientSavePathController;
  late final TextEditingController _localRootPathController;
  int? _selectedLibraryId;
  late DownloadClientKind _kind;
  final Object _probeScope = Object();

  bool get _isEditing => widget.initialClient != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialClient;
    _kind = initial?.kind ?? DownloadClientKind.qbittorrent;
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
    if (ref.read(downloadClientProbeProvider(_probeScope)).busy) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final value = _snapshotFormValue();
    if (_isEditing) {
      Navigator.of(context).pop(value.toUpdatePayload());
      return;
    }

    Navigator.of(context).pop(value.toCreatePayload());
  }

  DownloadClientFormValue _snapshotFormValue() {
    return DownloadClientFormValue.fromControllers(
      kind: _kind,
      nameController: _nameController,
      baseUrlController: _baseUrlController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      clientSavePathController: _clientSavePathController,
      localRootPathController: _localRootPathController,
      mediaLibraryId: _selectedLibraryId,
    );
  }

  DownloadClientFormValue? _validatedFormValue() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return null;
    }
    return _snapshotFormValue();
  }

  Future<void> _handleConnectivityChipTap() async {
    final value = _validatedFormValue();
    if (value == null) return;
    final payload = value.toProbeTestPayload(
      clientId: widget.initialClient?.id,
    );
    final api = ref.read(downloadClientsApiProvider);
    await handleProbeConnectivityTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: () => api.probeTestClient(payload),
      openDialog: (result) => _openConnectivityDialog(result, payload),
    );
  }

  Future<void> _handleStorageChipTap() async {
    final value = _validatedFormValue();
    if (value == null) return;
    final payload = value.toProbeStorageTestPayload(
      clientId: widget.initialClient?.id,
    );
    final api = ref.read(downloadClientsApiProvider);
    await handleProbeStorageTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: () => api.probeStorageTestClient(payload),
      openDialog:
          (result) => _openStorageDialog(result, payload, value.baseUrl),
    );
  }

  Future<void> _openConnectivityDialog(
    DownloadClientTestResultDto result,
    DownloadClientProbeTestPayload payload,
  ) async {
    final api = ref.read(downloadClientsApiProvider);
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientTestResultDialog(
            initialResult: result,
            onRerun: () => api.probeTestClient(payload),
            onResultChanged:
                ref
                    .read(downloadClientProbeProvider(_probeScope).notifier)
                    .applyConnectivityResult,
          ),
    );
  }

  Future<void> _openStorageDialog(
    DownloadClientStorageTestResultDto result,
    DownloadClientProbeStorageTestPayload payload,
    String baseUrl,
  ) async {
    final api = ref.read(downloadClientsApiProvider);
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientStorageTestResultDialog(
            initialResult: result,
            clientBaseUrl: baseUrl,
            onRerun: () => api.probeStorageTestClient(payload),
            onResultChanged:
                ref
                    .read(downloadClientProbeProvider(_probeScope).notifier)
                    .applyStorageResult,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final probe = ref.watch(downloadClientProbeProvider(_probeScope));
    final busy = probe.busy;

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
                kind: _kind,
                onKindChanged:
                    (value) => setState(() {
                      _kind = value;
                      _selectedLibraryId = null;
                    }),
                selectedLibraryId: _selectedLibraryId,
                onLibraryChanged:
                    (value) => setState(() {
                      _selectedLibraryId = value;
                    }),
                isEditing: _isEditing,
                enabled: !busy,
                credentialsLayout: DownloadClientCredentialsLayout.horizontal,
                onSubmitted: _submit,
              ),
              if (_kind == DownloadClientKind.qbittorrent) ...[
                SizedBox(height: spacing.lg),
                DownloadClientEditorProbeChips(
                  keyPrefix: 'download-client-dialog',
                  busy: busy,
                  connectivityState: probe.connectivityChipState,
                  storageState: probe.storageChipState,
                  connectivityDetail: probe.connectivityChipDetail,
                  storageDetail: probe.storageChipDetail,
                  onConnectivityTap: _handleConnectivityChipTap,
                  onStorageTap: _handleStorageChipTap,
                ),
              ],
              SizedBox(height: spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed:
                          busy ? null : () => Navigator.of(context).pop(),
                      label: '取消',
                    ),
                  ),
                  SizedBox(width: context.appSpacing.md),
                  Expanded(
                    child: AppButton(
                      onPressed: busy ? null : _submit,
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
