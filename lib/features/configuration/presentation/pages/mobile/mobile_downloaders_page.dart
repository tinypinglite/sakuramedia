import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileDownloadersPage extends ConsumerStatefulWidget {
  const MobileDownloadersPage({super.key});

  @override
  ConsumerState<MobileDownloadersPage> createState() =>
      _MobileDownloadersPageState();
}

class _MobileDownloadersPageState extends ConsumerState<MobileDownloadersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await Future.wait<void>([
        ref.read(downloadClientsProvider.notifier).reload(),
        ref.read(mediaLibrariesProvider.notifier).reload(),
        ref.read(mediaProviderCatalogProvider.notifier).reload(),
      ]);
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。'));
      }
    }
  }

  Future<void> _createClient(
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showMobileDownloaderEditorDrawer(
      context,
      libraries: libraries,
      providers: providers,
    );
  }

  Future<void> _editClient(
    DownloadClientDto client,
    List<MediaLibraryDto> libraries,
    List<MediaProviderDto> providers,
  ) async {
    await showMobileDownloaderEditorDrawer(
      context,
      libraries: libraries,
      providers: providers,
      initialClient: client,
    );
  }

  Future<void> _deleteClient(DownloadClientDto client) {
    return showAppConfigDeleteConfirm(
      context: context,
      title: '删除下载器',
      message: '确认删除下载器“${client.name}”？该操作不会删除下载任务。',
      dialogKey: const Key('mobile-downloader-delete-drawer'),
      confirmKey: const Key('mobile-downloader-delete-confirm-button'),
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final clientsAsync = ref.watch(downloadClientsProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final providersAsync = ref.watch(mediaProviderCatalogProvider);

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

    final loading =
        clientsAsync.isLoading ||
        librariesAsync.isLoading ||
        providersAsync.isLoading;
    final error = clientsAsync.error ?? librariesAsync.error;

    return ColoredBox(
      key: const Key('mobile-settings-downloaders'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.sm,
              spacing.md,
              spacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppTabBar(
                controller: _tabController,
                variant: AppTabBarVariant.compact,
                tabs: const [
                  Tab(
                    key: Key('mobile-downloaders-tab-downloaders'),
                    text: '下载器',
                  ),
                  Tab(key: Key('mobile-downloaders-tab-guide'), text: '接入说明'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDownloadersTab(
                  context,
                  clients: clients,
                  libraries: allLibraries,
                  downloadableLibraries: downloadableLibraries,
                  providers: providers,
                  loading: loading,
                  error: error,
                  providerCatalogUnavailable: providersAsync.hasError,
                ),
                _buildGuideTab(
                  context,
                  clients: clients,
                  libraries: downloadableLibraries,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-downloaders-create-button'),
                label: '新增下载器',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed:
                    loading || error != null || downloadableLibraries.isEmpty
                    ? null
                    : () => _createClient(downloadableLibraries, providers),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadersTab(
    BuildContext context, {
    required List<DownloadClientDto> clients,
    required List<MediaLibraryDto> libraries,
    required List<MediaLibraryDto> downloadableLibraries,
    required List<MediaProviderDto> providers,
    required bool loading,
    required Object? error,
    required bool providerCatalogUnavailable,
  }) {
    final spacing = context.appSpacing;
    final providersByKey = <String, MediaProviderDto>{
      for (final provider in providers) provider.providerKey: provider,
    };
    final librariesById = <int, MediaLibraryDto>{
      for (final library in libraries) library.id: library,
    };
    return AppAdaptiveRefreshScrollView(
      onRefresh: _refresh,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.sm,
            spacing.md,
            spacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppNoticeCard(
                  key: const Key('mobile-downloaders-overview-card'),
                  title: '下载器把索引器推送的资源请求交给对应 Provider 执行。',
                  description: '先选择支持下载的媒体库，再填写该 Provider 提供的配置字段。',
                  stats: [
                    AppNoticeStat(
                      label: '已配置下载器数',
                      value: '${clients.length}',
                      valueSize: AppTextSize.s18,
                    ),
                    AppNoticeStat(
                      label: '可用媒体库数',
                      value: '${downloadableLibraries.length}',
                      valueSize: AppTextSize.s18,
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                if (providerCatalogUnavailable) ...[
                  const AppNoticeCard(
                    key: Key('mobile-downloaders-provider-catalog-error'),
                    leadingIcon: Icons.warning_amber_rounded,
                    description:
                        'Provider 目录暂不可用，已有下载器仍可管理；恢复插件目录后才能新建或编辑 Provider 配置。',
                  ),
                  SizedBox(height: spacing.md),
                ],
                if (loading)
                  const _MobileDownloadersLoadingSection()
                else if (error != null)
                  AppMobileSectionError(
                    key: const Key('mobile-downloaders-error-state'),
                    title: '下载器加载失败',
                    message: apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。'),
                    onRetry: _refresh,
                    retryButtonKey: const Key(
                      'mobile-downloaders-retry-button',
                    ),
                  )
                else if (clients.isEmpty)
                  const MobileConfigEmptyCard(
                    key: Key('mobile-downloaders-empty-state'),
                    message: '还没有下载器配置',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < clients.length; index++) ...[
                        if (index > 0) SizedBox(height: spacing.sm),
                        _MobileDownloaderCard(
                          client: clients[index],
                          mediaLibrary: librariesById[clients[index].libraryId],
                          provider:
                              providersByKey[librariesById[clients[index]
                                      .libraryId]
                                  ?.providerKey],
                          onEdit: () => _editClient(
                            clients[index],
                            _librariesForEdit(
                              clients[index],
                              downloadableLibraries,
                              librariesById,
                            ),
                            providers,
                          ),
                          onDelete: () => _deleteClient(clients[index]),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideTab(
    BuildContext context, {
    required List<DownloadClientDto> clients,
    required List<MediaLibraryDto> libraries,
  }) {
    final readyLibraries = libraries.isNotEmpty;
    return AppAdaptiveRefreshScrollView(
      onRefresh: _refresh,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(context.appSpacing.md),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-libraries'),
                  title: '先准备媒体库',
                  description: '下载器必须绑定一个支持下载的媒体库，配置由对应 Provider 提供。',
                  tip: '如果列表为空，请先安装并配置支持下载的 Provider。',
                  badgeLabel: readyLibraries ? '已配置' : '待配置',
                  badgeTone: readyLibraries
                      ? AppBadgeTone.success
                      : AppBadgeTone.warning,
                  showShadow: true,
                  actionLabel: '前往媒体库',
                  onActionTap: () => GoRouter.of(
                    context,
                  ).push(mobileSettingsMediaLibrariesPath),
                ),
                SizedBox(height: context.appSpacing.md),
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-downloaders'),
                  title: '配置下载器',
                  description: '选择目标媒体库后，填写 Provider 目录定义的配置字段。',
                  tip: '敏感字段留空保存时会沿用已有值。',
                  badgeLabel: clients.isNotEmpty ? '已配置' : '待配置',
                  badgeTone: clients.isNotEmpty
                      ? AppBadgeTone.success
                      : AppBadgeTone.warning,
                  showShadow: true,
                  actionLabel: '切换到下载器',
                  onActionTap: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileDownloaderCard extends StatelessWidget {
  const _MobileDownloaderCard({
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
    return MobileEntityListCard(
      outerKey: Key('mobile-downloader-card-${client.id}'),
      bodyKey: Key('mobile-downloader-card-body-${client.id}'),
      leading: Container(
        width: context.appComponentTokens.iconSizeXl + spacing.md,
        height: context.appComponentTokens.iconSizeXl + spacing.md,
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: const Icon(Icons.cloud_download_outlined),
      ),
      title: Text(
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
      body: [
        SizedBox(height: spacing.xs),
        _DownloaderMetaLine(label: 'Provider', value: providerName),
        _DownloaderMetaLine(label: '媒体库', value: libraryName),
      ],
      onTap: onEdit,
      trailingAction: IconButton(
        key: Key('mobile-downloader-delete-${client.id}'),
        tooltip: '删除',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

class _DownloaderMetaLine extends StatelessWidget {
  const _DownloaderMetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

Future<DownloadClientDto?> showMobileDownloaderEditorDrawer(
  BuildContext context, {
  required List<MediaLibraryDto> libraries,
  required List<MediaProviderDto> providers,
  DownloadClientDto? initialClient,
}) {
  return showAppBottomDrawer<DownloadClientDto>(
    context: context,
    drawerKey: const Key('mobile-downloader-editor-drawer'),
    heightFactor: 0.9,
    builder: (_) => _MobileDownloaderEditorDrawer(
      libraries: libraries,
      providers: providers,
      initialClient: initialClient,
    ),
  );
}

class _MobileDownloaderEditorDrawer extends ConsumerStatefulWidget {
  const _MobileDownloaderEditorDrawer({
    required this.libraries,
    required this.providers,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final List<MediaProviderDto> providers;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<_MobileDownloaderEditorDrawer> createState() =>
      _MobileDownloaderEditorDrawerState();
}

class _MobileDownloaderEditorDrawerState
    extends ConsumerState<_MobileDownloaderEditorDrawer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late ProviderConfigFormController _providerConfigController;
  int? _selectedLibraryId;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;

  bool get _isEditing => widget.initialClient != null;

  MediaProviderDto? _providerForLibrary(int? libraryId) {
    if (libraryId == null) return null;
    MediaLibraryDto? library;
    for (final item in widget.libraries) {
      if (item.id == libraryId) {
        library = item;
        break;
      }
    }
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

  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _hasAttemptedSubmit = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = DownloadClientFormValue.fromControllers(
      nameController: _nameController,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
      libraryId: _selectedLibraryId,
      providerConfigAvailable:
          _providerForLibrary(_selectedLibraryId)?.supportsDownloads ?? false,
    );
    setState(() => _isSubmitting = true);
    try {
      final client = _isEditing
          ? await ref
                .read(downloadClientsProvider.notifier)
                .updateClient(
                  clientId: widget.initialClient!.id,
                  payload: value.toUpdatePayload(),
                )
          : await ref
                .read(downloadClientsProvider.notifier)
                .create(value.toCreatePayload());
      if (!mounted) return;
      showToast(_isEditing ? '下载器已更新' : '下载器已创建');
      Navigator.of(context).pop(client);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showToast(
        apiErrorMessage(error, fallback: _isEditing ? '更新下载器失败' : '创建下载器失败'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑下载器' : '新增下载器',
      subtitle: '配置由目标媒体库的 Provider 决定。',
      submitKey: const Key('mobile-downloader-submit-button'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: DownloadClientFormFields(
        nameController: _nameController,
        libraries: widget.libraries,
        selectedLibraryId: _selectedLibraryId,
        onLibraryChanged: _selectLibrary,
        providerConfigController: _providerConfigController,
        isEditing: _isEditing,
        enabled: !_isSubmitting,
        autovalidateMode: _autovalidateMode,
      ),
    );
  }
}

class _MobileDownloadersLoadingSection extends StatelessWidget {
  const _MobileDownloadersLoadingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == 2 ? 0 : context.appSpacing.sm,
          ),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.lgBorder,
            ),
          ),
        ),
      ),
    );
  }
}
