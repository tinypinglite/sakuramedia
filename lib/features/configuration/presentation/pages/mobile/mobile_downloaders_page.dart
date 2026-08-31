import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_state.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/download_client_probe_interactions.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_client_probe_provider.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_info_block.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

/// 移动端下载器卡片的探针状态快照。
/// - 会话内 in-memory,不落库;编辑保存/删除时清空对应 clientId 的条目。
/// - `probing` 态由抽屉内运行状态覆盖,不进入快照。
/// - 作为详情抽屉 controller 的初始种子,详情抽屉每次跑完通过回调回写。
class _MobileDownloaderProbeSnapshot {
  const _MobileDownloaderProbeSnapshot({
    this.connectivityChipState = DownloadClientProbeChipState.notTested,
    this.storageChipState = DownloadClientProbeChipState.notTested,
    this.connectivityResult,
    this.storageResult,
  });

  final DownloadClientProbeChipState connectivityChipState;
  final DownloadClientProbeChipState storageChipState;
  final DownloadClientTestResultDto? connectivityResult;
  final DownloadClientStorageTestResultDto? storageResult;
}

class MobileDownloadersPage extends ConsumerStatefulWidget {
  const MobileDownloadersPage({super.key});

  @override
  ConsumerState<MobileDownloadersPage> createState() =>
      _MobileDownloadersPageState();
}

class _MobileDownloadersPageState extends ConsumerState<MobileDownloadersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<DownloadClientDto> _clients = const <DownloadClientDto>[];
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  IndexerSettingsDto _indexerSettings = const IndexerSettingsDto(
    indexers: <IndexerEntryDto>[],
  );
  bool _isLoading = true;
  String? _errorMessage;
  final Map<int, _MobileDownloaderProbeSnapshot> _probeSnapshots =
      <int, _MobileDownloaderProbeSnapshot>{};

  bool get _hasLinkedIndexer =>
      _indexerSettings.indexers.any((item) => item.downloadClients.isNotEmpty);

  bool get _hasLibraries => _libraries.isNotEmpty;

  int get _linkedLibraryCount =>
      _clients
          .map((item) => item.mediaLibraryId)
          .where((item) => item > 0)
          .toSet()
          .length;

  int get _savedPasswordCount =>
      _clients.where((item) => item.hasPassword).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

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
                _buildDownloadersTab(context),
                _buildGuideTab(context),
              ],
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
                key: const Key('mobile-downloaders-create-button'),
                label: '新增下载器',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _hasLibraries ? _handleCreateClient : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadersTab(BuildContext context) {
    final spacing = context.appSpacing;

    return AppAdaptiveRefreshScrollView(
      onRefresh: _refreshData,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
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
                  title: '下载入口负责接收索引器推送的资源请求，并把任务交给 qBittorrent 或 115。',
                  description: 'qBittorrent 需要配置路径映射；115 离线入口直接复用云媒体库登录状态。',
                  stats: [
                    AppNoticeStat(
                      label: '已配置下载器数',
                      value: '${_clients.length}',
                      valueSize: AppTextSize.s18,
                    ),
                    AppNoticeStat(
                      label: '关联媒体库数',
                      value: '$_linkedLibraryCount',
                      valueSize: AppTextSize.s18,
                    ),
                    AppNoticeStat(
                      label: 'qB 已保存密码数',
                      value: '$_savedPasswordCount',
                      valueSize: AppTextSize.s18,
                    ),
                  ],
                ),
                SizedBox(height: spacing.md),
                _buildDownloadersSection(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideTab(BuildContext context) {
    final spacing = context.appSpacing;

    return AppAdaptiveRefreshScrollView(
      onRefresh: _refreshData,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
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
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-libraries'),
                  title: '先准备媒体库',
                  description: 'qBittorrent 入口绑定本地媒体库；115 离线入口绑定已登录的 115 媒体库。',
                  tip: '先确认媒体库类型与目标下载方式一致。',
                  badgeLabel: _hasLibraries ? '已配置' : '待配置',
                  badgeTone:
                      _hasLibraries
                          ? AppBadgeTone.success
                          : AppBadgeTone.warning,
                  showShadow: true,
                  actionLabel: '前往媒体库',
                  onActionTap:
                      () => GoRouter.of(
                        context,
                      ).push(mobileSettingsMediaLibrariesPath),
                ),
                SizedBox(height: spacing.md),
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-downloaders'),
                  title: '再配置下载器',
                  description: '下载入口负责接收索引器推送的资源请求，并选择实际执行下载的服务。',
                  tip: 'qBittorrent 需填写连接与路径；115 离线只需选择对应云媒体库。',
                  badgeLabel: _clients.isNotEmpty ? '已配置' : '待配置',
                  badgeTone:
                      _clients.isNotEmpty
                          ? AppBadgeTone.success
                          : AppBadgeTone.warning,
                  showShadow: true,
                  actionLabel: '切换到下载器',
                  onActionTap: () => _tabController.animateTo(0),
                ),
                SizedBox(height: spacing.md),
                MobileConfigOnboardingCard(
                  key: const Key('mobile-downloaders-guide-step-indexers'),
                  title: '最后把索引器绑定到下载器',
                  description: '只有索引器绑定到下载器，影片详情里的资源搜索结果才能投递到对应客户端。',
                  tip: '常见问题：未绑定下载器时，搜索结果会提示先创建下载器。',
                  badgeLabel: _hasLinkedIndexer ? '已配置' : '待配置',
                  badgeTone:
                      _hasLinkedIndexer
                          ? AppBadgeTone.success
                          : AppBadgeTone.warning,
                  showShadow: true,
                  actionLabel: '查看索引器',
                  onActionTap:
                      () =>
                          GoRouter.of(context).push(mobileSettingsIndexersPath),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadersSection(BuildContext context) {
    if (_isLoading) {
      return const _MobileDownloadersLoadingSection();
    }
    if (_errorMessage != null) {
      return AppMobileSectionError(
        key: const Key('mobile-downloaders-error-state'),
        title: '下载器加载失败',
        message: _errorMessage!,
        onRetry: _retryData,
        retryButtonKey: const Key('mobile-downloaders-retry-button'),
      );
    }
    if (_clients.isEmpty) {
      return const MobileConfigEmptyCard(
        key: Key('mobile-downloaders-empty-state'),
        message: '还没有下载器配置',
      );
    }

    final librariesById = <int, MediaLibraryDto>{
      for (final library in _libraries) library.id: library,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _clients
          .expand(
            (client) => <Widget>[
              _buildDownloaderCard(
                context,
                client: client,
                mediaLibrary: librariesById[client.mediaLibraryId],
                probeSnapshot:
                    _probeSnapshots[client.id] ??
                    const _MobileDownloaderProbeSnapshot(),
              ),
              if (client != _clients.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Widget _buildDownloaderCard(
    BuildContext context, {
    required DownloadClientDto client,
    required MediaLibraryDto? mediaLibrary,
    required _MobileDownloaderProbeSnapshot probeSnapshot,
  }) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final avatarSide = componentTokens.iconSizeXl + spacing.md;
    final passwordTone =
        client.isCloud115
            ? AppBadgeTone.info
            : client.hasPassword
            ? AppBadgeTone.success
            : AppBadgeTone.warning;
    final passwordLabel =
        client.isCloud115
            ? client.kind.label
            : client.hasPassword
            ? '已保存密码'
            : '待补密码';

    return MobileEntityListCard(
      outerKey: Key('mobile-downloader-card-${client.id}'),
      bodyKey: Key('mobile-downloader-card-body-${client.id}'),
      leading: Container(
        width: avatarSide,
        height: avatarSide,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Icon(
          client.isCloud115
              ? Icons.cloud_outlined
              : Icons.download_for_offline_outlined,
          size: componentTokens.iconSizeMd,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        client.name,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      titleTrailing: AppBadge(
        label: passwordLabel,
        tone: passwordTone,
        size: AppBadgeSize.compact,
      ),
      body: [
        SizedBox(height: spacing.xs),
        Text(
          client.isCloud115 ? '使用媒体库账号提交 115 离线下载' : client.baseUrl,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        if (client.isQbittorrent) ...[
          _DownloaderMetaLine(label: '用户名', value: client.username),
          SizedBox(height: spacing.xs),
        ],
        _DownloaderMetaLine(
          label: '目标媒体库',
          value: mediaLibrary?.name ?? '未关联媒体库',
        ),
        if (client.isQbittorrent) ...[
          SizedBox(height: spacing.xs),
          _DownloaderMetaLine(
            label: 'qBittorrent保存路径',
            value: client.clientSavePath,
          ),
          SizedBox(height: spacing.xs),
          _DownloaderMetaLine(label: '本地访问路径', value: client.localRootPath),
        ],
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            if (client.isQbittorrent)
              DownloadClientProbeStatusChip(
                key: Key('mobile-downloader-card-probe-test-${client.id}'),
                label: '连通性',
                state: probeSnapshot.connectivityChipState,
                detail: probeChipDetail(
                  probeSnapshot.connectivityChipState,
                  elapsedMs: probeSnapshot.connectivityResult?.elapsedMs,
                ),
                onTap: null,
              ),
            DownloadClientProbeStatusChip(
              key: Key(
                'mobile-downloader-card-probe-storage-test-${client.id}',
              ),
              label: '目录映射',
              state: probeSnapshot.storageChipState,
              detail: probeChipDetail(
                probeSnapshot.storageChipState,
                elapsedMs: probeSnapshot.storageResult?.elapsedMs,
              ),
              onTap: null,
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Text(
          '更新时间: ${formatUpdatedAtLabel(client.updatedAt) ?? '未知'}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
      onTap: () => _handleShowDetail(client),
    );
  }

  void _mergeConnectivityResult(
    int clientId,
    DownloadClientTestResultDto result,
  ) {
    setState(() {
      final prev =
          _probeSnapshots[clientId] ?? const _MobileDownloaderProbeSnapshot();
      _probeSnapshots[clientId] = _MobileDownloaderProbeSnapshot(
        connectivityChipState: probeChipStateFromConnectivity(result),
        connectivityResult: result,
        storageChipState: prev.storageChipState,
        storageResult: prev.storageResult,
      );
    });
  }

  void _mergeStorageResult(
    int clientId,
    DownloadClientStorageTestResultDto result,
  ) {
    setState(() {
      final prev =
          _probeSnapshots[clientId] ?? const _MobileDownloaderProbeSnapshot();
      _probeSnapshots[clientId] = _MobileDownloaderProbeSnapshot(
        connectivityChipState: prev.connectivityChipState,
        connectivityResult: prev.connectivityResult,
        storageChipState: probeChipStateFromStorage(result),
        storageResult: result,
      );
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        ref.read(downloadClientsProvider.future),
        ref.read(mediaLibrariesProvider.future),
        ref.read(indexerSettingsProvider.future),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _indexerSettings = (results[2] as IndexerSettingsState).draft;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _refreshData() async {
    final messages = await Future.wait<String?>([
      ref.read(downloadClientsProvider.notifier).refresh(),
      ref.read(mediaLibrariesProvider.notifier).refresh(),
      ref.read(indexerSettingsProvider.notifier).refresh(),
    ]);
    final message = messages.whereType<String>().firstOrNull;
    if (message != null) {
      if (mounted) showToast(message);
      return;
    }
    try {
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = ref.read(downloadClientsProvider).requireValue;
        _libraries = ref.read(mediaLibrariesProvider).requireValue;
        _indexerSettings = ref.read(indexerSettingsProvider).requireValue.draft;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。'));
    }
  }

  Future<void> _retryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait<void>([
        ref.read(downloadClientsProvider.notifier).reload(),
        ref.read(mediaLibrariesProvider.notifier).reload(),
        ref.read(indexerSettingsProvider.notifier).reload(),
      ]);
      if (!mounted) return;
      final clients = ref.read(downloadClientsProvider).requireValue;
      final libraries = ref.read(mediaLibrariesProvider).requireValue;
      final settings = ref.read(indexerSettingsProvider).requireValue;
      setState(() {
        _clients = clients;
        _libraries = libraries;
        _indexerSettings = settings.draft;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _handleCreateClient() async {
    final createdClient = await showMobileDownloaderEditorDrawer(
      context,
      libraries: _libraries,
    );
    if (!mounted || createdClient == null) {
      return;
    }
    _upsertClient(createdClient);
    unawaited(_syncDataInBackground());
  }

  Future<void> _handleEditClient(DownloadClientDto client) async {
    final updatedClient = await showMobileDownloaderEditorDrawer(
      context,
      libraries: _libraries,
      initialClient: client,
    );
    if (!mounted || updatedClient == null) {
      return;
    }
    _upsertClient(updatedClient);
    unawaited(_syncDataInBackground());
  }

  Future<void> _handleDeleteClient(DownloadClientDto client) async {
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除下载器',
      message: '确认删除下载器"${client.name}"？该操作不会删除已有下载任务，但索引器绑定关系可能需要重新调整。',
      dialogKey: const Key('mobile-downloader-delete-drawer'),
      confirmKey: const Key('mobile-downloader-delete-confirm-button'),
      onDelete:
          () => ref.read(downloadClientsProvider.notifier).delete(client.id),
      successToast: '下载器已删除',
      failureFallback: '删除下载器失败',
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() {
      _clients = _clients
          .where((item) => item.id != client.id)
          .toList(growable: false);
      _probeSnapshots.remove(client.id);
      _errorMessage = null;
    });
  }

  Future<void> _handleShowDetail(DownloadClientDto client) async {
    final detailAction = await _showMobileDownloaderDetailDrawer(
      context,
      client: client,
      mediaLibrary: _libraryById(client.mediaLibraryId),
      initialSnapshot:
          _probeSnapshots[client.id] ?? const _MobileDownloaderProbeSnapshot(),
      onConnectivityResult:
          (result) => _mergeConnectivityResult(client.id, result),
      onStorageResult: (result) => _mergeStorageResult(client.id, result),
    );
    if (!mounted || detailAction == null) {
      return;
    }
    switch (detailAction) {
      case MobileDownloaderDetailAction.edit:
        await _handleEditClient(client);
      case MobileDownloaderDetailAction.delete:
        await _handleDeleteClient(client);
    }
  }

  Future<void> _syncDataInBackground() async {
    try {
      final results = await Future.wait<Object>([
        ref.read(downloadClientsProvider.future),
        ref.read(mediaLibrariesProvider.future),
        ref.read(indexerSettingsProvider.future),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _indexerSettings = (results[2] as IndexerSettingsState).draft;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。'));
    }
  }

  void _upsertClient(DownloadClientDto client) {
    ref.read(downloadClientsProvider.notifier).upsert(client);
    final nextClients = List<DownloadClientDto>.of(_clients);
    final index = nextClients.indexWhere((item) => item.id == client.id);
    if (index >= 0) {
      nextClients[index] = client;
    } else {
      nextClients.add(client);
    }
    // 配置改了 → 老探针结果作废,回到未检测态。
    _probeSnapshots.remove(client.id);
    setState(() {
      _clients = nextClients;
      _errorMessage = null;
    });
  }

  MediaLibraryDto? _libraryById(int libraryId) {
    for (final library in _libraries) {
      if (library.id == libraryId) {
        return library;
      }
    }
    return null;
  }
}

Future<DownloadClientDto?> showMobileDownloaderEditorDrawer(
  BuildContext context, {
  required List<MediaLibraryDto> libraries,
  DownloadClientDto? initialClient,
}) {
  return showAppBottomDrawer<DownloadClientDto>(
    context: context,
    drawerKey: const Key('mobile-downloader-editor-drawer'),
    heightFactor: 0.82,
    builder: (drawerContext) {
      return _MobileDownloaderEditorDrawer(
        libraries: libraries,
        initialClient: initialClient,
      );
    },
  );
}

Future<MobileDownloaderDetailAction?> _showMobileDownloaderDetailDrawer(
  BuildContext context, {
  required DownloadClientDto client,
  required MediaLibraryDto? mediaLibrary,
  _MobileDownloaderProbeSnapshot initialSnapshot =
      const _MobileDownloaderProbeSnapshot(),
  ValueChanged<DownloadClientTestResultDto>? onConnectivityResult,
  ValueChanged<DownloadClientStorageTestResultDto>? onStorageResult,
}) {
  return showAppBottomDrawer<MobileDownloaderDetailAction>(
    context: context,
    drawerKey: const Key('mobile-downloader-detail-drawer'),
    heightFactor: 0.62,
    builder: (drawerContext) {
      return _MobileDownloaderDetailDrawer(
        client: client,
        mediaLibrary: mediaLibrary,
        initialSnapshot: initialSnapshot,
        onConnectivityResult: onConnectivityResult,
        onStorageResult: onStorageResult,
      );
    },
  );
}

enum MobileDownloaderDetailAction { edit, delete }

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
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
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
          child: const _MobileDownloaderSkeletonCard(),
        ),
      ),
    );
  }
}

class _MobileDownloaderSkeletonCard extends StatelessWidget {
  const _MobileDownloaderSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBlock(
            width: context.appComponentTokens.iconSizeXl + spacing.md,
            height: context.appComponentTokens.iconSizeXl + spacing.md,
            radius: context.appRadius.mdBorder,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonBlock(width: 116, height: 16),
                SizedBox(height: spacing.xs),
                const AppSkeletonBlock(width: 188, height: 12),
                SizedBox(height: spacing.sm),
                const AppSkeletonBlock(width: 132, height: 12),
                SizedBox(height: spacing.xs),
                const AppSkeletonBlock(width: 168, height: 12),
                SizedBox(height: spacing.xs),
                const AppSkeletonBlock(width: 148, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDownloaderEditorDrawer extends ConsumerStatefulWidget {
  const _MobileDownloaderEditorDrawer({
    required this.libraries,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final DownloadClientDto? initialClient;

  @override
  ConsumerState<_MobileDownloaderEditorDrawer> createState() =>
      _MobileDownloaderEditorDrawerState();
}

class _MobileDownloaderEditorDrawerState
    extends ConsumerState<_MobileDownloaderEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _clientSavePathController;
  late final TextEditingController _localRootPathController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _baseUrlFocusNode;
  late final FocusNode _usernameFocusNode;
  late final FocusNode _passwordFocusNode;
  late final FocusNode _clientSavePathFocusNode;
  late final FocusNode _localRootPathFocusNode;
  late int? _selectedLibraryId;
  late DownloadClientKind _kind;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  final Object _probeScope = Object();

  bool get _isEditing => widget.initialClient != null;

  bool get _busy =>
      _isSubmitting || ref.read(downloadClientProbeProvider(_probeScope)).busy;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initialClient = widget.initialClient;
    _kind = initialClient?.kind ?? DownloadClientKind.qbittorrent;
    _nameController = TextEditingController(text: initialClient?.name ?? '');
    _baseUrlController = TextEditingController(
      text: initialClient?.baseUrl ?? '',
    );
    _usernameController = TextEditingController(
      text: initialClient?.username ?? '',
    );
    _passwordController = TextEditingController();
    _clientSavePathController = TextEditingController(
      text: initialClient?.clientSavePath ?? '',
    );
    _localRootPathController = TextEditingController(
      text: initialClient?.localRootPath ?? '',
    );
    _nameFocusNode = FocusNode();
    _baseUrlFocusNode = FocusNode();
    _usernameFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _clientSavePathFocusNode = FocusNode();
    _localRootPathFocusNode = FocusNode();
    _selectedLibraryId = initialClient?.mediaLibraryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _clientSavePathController.dispose();
    _localRootPathController.dispose();
    _nameFocusNode.dispose();
    _baseUrlFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _clientSavePathFocusNode.dispose();
    _localRootPathFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final probe = ref.watch(downloadClientProbeProvider(_probeScope));
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑下载器' : '新增下载器',
      subtitle:
          _kind == DownloadClientKind.cloud115
              ? '选择 115 媒体库即可启用离线下载。'
              : '维护下载器服务地址、路径映射和媒体库绑定关系。',
      submitKey: const Key('mobile-downloader-submit-button'),
      isSubmitting: _isSubmitting,
      submitDisabled: probe.busy,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DownloadClientFormFields(
            nameController: _nameController,
            baseUrlController: _baseUrlController,
            usernameController: _usernameController,
            passwordController: _passwordController,
            clientSavePathController: _clientSavePathController,
            localRootPathController: _localRootPathController,
            libraries: widget.libraries,
            kind: _kind,
            onKindChanged: (value) {
              setState(() {
                _kind = value;
                _selectedLibraryId = null;
              });
            },
            selectedLibraryId: _selectedLibraryId,
            onLibraryChanged: (value) {
              setState(() {
                _selectedLibraryId = value;
              });
            },
            isEditing: _isEditing,
            enabled: !_busy,
            autovalidateMode: _autovalidateMode,
            nameFocusNode: _nameFocusNode,
            baseUrlFocusNode: _baseUrlFocusNode,
            usernameFocusNode: _usernameFocusNode,
            passwordFocusNode: _passwordFocusNode,
            clientSavePathFocusNode: _clientSavePathFocusNode,
            localRootPathFocusNode: _localRootPathFocusNode,
            onSubmitted: _submit,
          ),
          if (_kind == DownloadClientKind.qbittorrent) ...[
            SizedBox(height: spacing.lg),
            DownloadClientEditorProbeChips(
              keyPrefix: 'mobile-downloader',
              busy: _busy,
              connectivityState: probe.connectivityChipState,
              storageState: probe.storageChipState,
              connectivityDetail: probe.connectivityChipDetail,
              storageDetail: probe.storageChipDetail,
              onConnectivityTap: _handleConnectivityChipTap,
              onStorageTap: _handleStorageChipTap,
            ),
          ],
        ],
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

    setState(() {
      _isSubmitting = true;
    });

    final value = DownloadClientFormValue.fromControllers(
      kind: _kind,
      nameController: _nameController,
      baseUrlController: _baseUrlController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      clientSavePathController: _clientSavePathController,
      localRootPathController: _localRootPathController,
      mediaLibraryId: _selectedLibraryId,
    );

    try {
      final client =
          _isEditing
              ? await ref
                  .read(downloadClientsProvider.notifier)
                  .updateClient(
                    clientId: widget.initialClient!.id,
                    payload: value.toUpdatePayload(),
                  )
              : await ref
                  .read(downloadClientsProvider.notifier)
                  .create(value.toCreatePayload());
      if (!mounted) {
        return;
      }
      showToast(_isEditing ? '下载器已更新' : '下载器已创建');
      Navigator.of(context).pop(client);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: _isEditing ? '更新下载器失败' : '创建下载器失败'),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  DownloadClientFormValue? _validatedFormValue() {
    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() => _hasAttemptedSubmit = true);
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return null;
    }
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
}

class _MobileDownloaderDetailDrawer extends ConsumerStatefulWidget {
  const _MobileDownloaderDetailDrawer({
    required this.client,
    required this.mediaLibrary,
    required this.initialSnapshot,
    required this.onConnectivityResult,
    required this.onStorageResult,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final _MobileDownloaderProbeSnapshot initialSnapshot;
  final ValueChanged<DownloadClientTestResultDto>? onConnectivityResult;
  final ValueChanged<DownloadClientStorageTestResultDto>? onStorageResult;

  @override
  ConsumerState<_MobileDownloaderDetailDrawer> createState() =>
      _MobileDownloaderDetailDrawerState();
}

class _MobileDownloaderDetailDrawerState
    extends ConsumerState<_MobileDownloaderDetailDrawer> {
  final Object _probeScope = Object();

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(
      downloadClientProbeProvider(_probeScope).notifier,
    );
    final connectivity = widget.initialSnapshot.connectivityResult;
    final storage = widget.initialSnapshot.storageResult;
    if (connectivity != null) notifier.applyConnectivityResult(connectivity);
    if (storage != null) notifier.applyStorageResult(storage);
  }

  Future<void> _handleConnectivityAction() async {
    final api = ref.read(downloadClientsApiProvider);
    await handleProbeConnectivityTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: () => api.testClient(widget.client.id),
      openDialog: _openConnectivityDialog,
    );
    final result =
        ref.read(downloadClientProbeProvider(_probeScope)).connectivityResult;
    if (result != null) widget.onConnectivityResult?.call(result);
  }

  Future<void> _handleStorageAction() async {
    final api = ref.read(downloadClientsApiProvider);
    await handleProbeStorageTap(
      context: context,
      probe: ref.read(downloadClientProbeProvider(_probeScope).notifier),
      runTest: () => api.storageTestClient(widget.client.id),
      openDialog: _openStorageDialog,
    );
    final result =
        ref.read(downloadClientProbeProvider(_probeScope)).storageResult;
    if (result != null) widget.onStorageResult?.call(result);
  }

  Future<void> _openConnectivityDialog(
    DownloadClientTestResultDto result,
  ) async {
    final api = ref.read(downloadClientsApiProvider);
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientTestResultDialog(
            initialResult: result,
            onRerun: () => api.testClient(widget.client.id),
            onResultChanged: (next) {
              ref
                  .read(downloadClientProbeProvider(_probeScope).notifier)
                  .applyConnectivityResult(next);
              widget.onConnectivityResult?.call(next);
            },
          ),
    );
  }

  Future<void> _openStorageDialog(
    DownloadClientStorageTestResultDto result,
  ) async {
    final api = ref.read(downloadClientsApiProvider);
    await showDialog<void>(
      context: context,
      builder:
          (_) => DownloadClientStorageTestResultDialog(
            initialResult: result,
            clientBaseUrl: widget.client.baseUrl,
            onRerun: () => api.storageTestClient(widget.client.id),
            onResultChanged: (next) {
              ref
                  .read(downloadClientProbeProvider(_probeScope).notifier)
                  .applyStorageResult(next);
              widget.onStorageResult?.call(next);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final client = widget.client;
    final mediaLibrary = widget.mediaLibrary;
    final passwordLabel =
        client.isCloud115
            ? client.kind.label
            : client.hasPassword
            ? '已保存密码'
            : '待补密码';
    final probe = ref.watch(downloadClientProbeProvider(_probeScope));
    final busy = probe.busy;

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
                      client.name,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      client.isCloud115 ? '115 离线下载' : client.baseUrl,
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
              AppBadge(
                label: passwordLabel,
                tone:
                    client.isCloud115
                        ? AppBadgeTone.info
                        : client.hasPassword
                        ? AppBadgeTone.success
                        : AppBadgeTone.warning,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppInfoBlock(label: '类型', value: client.kind.label),
          if (client.isQbittorrent) ...[
            SizedBox(height: spacing.sm),
            AppInfoBlock(label: '用户名', value: client.username),
          ],
          AppInfoBlock(label: '目标媒体库', value: mediaLibrary?.name ?? '未关联媒体库'),
          if (client.isQbittorrent) ...[
            SizedBox(height: spacing.sm),
            AppInfoBlock(
              label: 'qBittorrent保存路径',
              value: client.clientSavePath,
            ),
            SizedBox(height: spacing.sm),
            AppInfoBlock(label: '本地访问路径', value: client.localRootPath),
          ],
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: '更新时间',
            value: formatUpdatedAtLabel(client.updatedAt) ?? '未知',
          ),
          SizedBox(height: spacing.lg),
          Text(
            '诊断',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              if (client.isQbittorrent)
                DownloadClientProbeStatusChip(
                  key: const Key('mobile-downloader-detail-probe-test-button'),
                  label: '连通性',
                  state: probe.connectivityChipState,
                  detail: probe.connectivityChipDetail,
                  onTap: busy ? null : _handleConnectivityAction,
                ),
              DownloadClientProbeStatusChip(
                key: const Key(
                  'mobile-downloader-detail-probe-storage-test-button',
                ),
                label: '目录映射',
                state: probe.storageChipState,
                detail: probe.storageChipDetail,
                onTap: busy ? null : _handleStorageAction,
              ),
            ],
          ),
          SizedBox(height: spacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('mobile-downloader-detail-edit-button'),
                  label: '编辑',
                  variant: AppButtonVariant.primary,
                  onPressed:
                      busy
                          ? null
                          : () => Navigator.of(
                            context,
                          ).pop(MobileDownloaderDetailAction.edit),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('mobile-downloader-detail-delete-button'),
                  label: '删除',
                  variant: AppButtonVariant.danger,
                  onPressed:
                      busy
                          ? null
                          : () => Navigator.of(
                            context,
                          ).pop(MobileDownloaderDetailAction.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
