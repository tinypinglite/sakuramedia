import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_onboarding_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/download_client_probe_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/download_client_probe_interactions.dart';
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

class MobileDownloadersPage extends StatefulWidget {
  const MobileDownloadersPage({super.key});

  @override
  State<MobileDownloadersPage> createState() => _MobileDownloadersPageState();
}

class _MobileDownloadersPageState extends State<MobileDownloadersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<DownloadClientDto> _clients = const <DownloadClientDto>[];
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  IndexerSettingsDto _indexerSettings = const IndexerSettingsDto(
    type: '',
    apiKey: '',
    indexers: <IndexerEntryDto>[],
  );
  bool _isLoading = true;
  String? _errorMessage;
  final Map<int, _MobileDownloaderProbeSnapshot> _probeSnapshots =
      <int, _MobileDownloaderProbeSnapshot>{};

  bool get _hasLinkedIndexer =>
      _indexerSettings.indexers.any((item) => item.downloadClientId > 0);

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
                  title: '下载器负责接收索引器推送的资源请求，并依赖媒体库路径映射完成落库。',
                  description: '建议先确认媒体库路径，再补全 qBittorrent 保存路径与本地访问路径。',
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
                      label: '已保存密码数',
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
                  description: '媒体库用于维护本地存储根路径，下载器创建前需要先明确映射位置。',
                  tip: '关键字段：媒体库名称、根路径。',
                  badgeLabel: _hasLibraries ? '已配置' : '待配置',
                  badgeTone: _hasLibraries
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
                  description: '下载器负责接收索引器推送的资源请求，并映射 qBittorrent 下载路径。',
                  tip: '关键字段：服务地址、qBittorrent 保存路径、本地访问路径。',
                  badgeLabel: _clients.isNotEmpty ? '已配置' : '待配置',
                  badgeTone: _clients.isNotEmpty
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
                  badgeTone: _hasLinkedIndexer
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
        onRetry: _loadData,
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
                probeSnapshot: _probeSnapshots[client.id] ??
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
        client.hasPassword ? AppBadgeTone.success : AppBadgeTone.warning;
    final passwordLabel = client.hasPassword ? '已保存密码' : '待补密码';

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
          Icons.download_for_offline_outlined,
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
          client.baseUrl,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        _DownloaderMetaLine(label: '用户名', value: client.username),
        SizedBox(height: spacing.xs),
        _DownloaderMetaLine(
          label: '目标媒体库',
          value: mediaLibrary?.name ?? '未关联媒体库',
        ),
        SizedBox(height: spacing.xs),
        _DownloaderMetaLine(
          label: 'qBittorrent保存路径',
          value: client.clientSavePath,
        ),
        SizedBox(height: spacing.xs),
        _DownloaderMetaLine(label: '本地访问路径', value: client.localRootPath),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
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
        context.read<DownloadClientsApi>().getClients(),
        context.read<MediaLibrariesApi>().getLibraries(),
        context.read<IndexerSettingsApi>().getSettings(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _indexerSettings = results[2] as IndexerSettingsDto;
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
    try {
      final results = await Future.wait<Object>([
        context.read<DownloadClientsApi>().getClients(),
        context.read<MediaLibrariesApi>().getLibraries(),
        context.read<IndexerSettingsApi>().getSettings(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _indexerSettings = results[2] as IndexerSettingsDto;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '下载器加载失败，请稍后重试。'));
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
    final api = context.read<DownloadClientsApi>();
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除下载器',
      message: '确认删除下载器"${client.name}"？该操作不会删除已有下载任务，但索引器绑定关系可能需要重新调整。',
      dialogKey: const Key('mobile-downloader-delete-drawer'),
      confirmKey: const Key('mobile-downloader-delete-confirm-button'),
      onDelete: () => api.deleteClient(client.id),
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
    unawaited(_syncDataInBackground());
  }

  Future<void> _handleShowDetail(DownloadClientDto client) async {
    final detailAction = await _showMobileDownloaderDetailDrawer(
      context,
      client: client,
      mediaLibrary: _libraryById(client.mediaLibraryId),
      initialSnapshot:
          _probeSnapshots[client.id] ??
          const _MobileDownloaderProbeSnapshot(),
      onConnectivityResult: (result) =>
          _mergeConnectivityResult(client.id, result),
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
        context.read<DownloadClientsApi>().getClients(),
        context.read<MediaLibrariesApi>().getLibraries(),
        context.read<IndexerSettingsApi>().getSettings(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _clients = results[0] as List<DownloadClientDto>;
        _libraries = results[1] as List<MediaLibraryDto>;
        _indexerSettings = results[2] as IndexerSettingsDto;
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

class _MobileDownloaderEditorDrawer extends StatefulWidget {
  const _MobileDownloaderEditorDrawer({
    required this.libraries,
    this.initialClient,
  });

  final List<MediaLibraryDto> libraries;
  final DownloadClientDto? initialClient;

  @override
  State<_MobileDownloaderEditorDrawer> createState() =>
      _MobileDownloaderEditorDrawerState();
}

class _MobileDownloaderEditorDrawerState
    extends State<_MobileDownloaderEditorDrawer> {
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
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  late final DownloadClientProbeController _probe;

  bool get _isEditing => widget.initialClient != null;

  bool get _busy => _isSubmitting || _probe.busy;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initialClient = widget.initialClient;
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
    _probe = DownloadClientProbeController()..addListener(_onProbeChanged);
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
    _probe.removeListener(_onProbeChanged);
    _probe.dispose();
    super.dispose();
  }

  void _onProbeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑下载器' : '新增下载器',
      subtitle: '维护下载器服务地址、路径映射和媒体库绑定关系。',
      submitKey: const Key('mobile-downloader-submit-button'),
      isSubmitting: _isSubmitting,
      submitDisabled: _probe.busy,
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
          SizedBox(height: spacing.lg),
          DownloadClientEditorProbeChips(
            keyPrefix: 'mobile-downloader',
            busy: _busy,
            connectivityState: _probe.connectivityChipState,
            storageState: _probe.storageChipState,
            connectivityDetail: _probe.connectivityChipDetail(),
            storageDetail: _probe.storageChipDetail(),
            onConnectivityTap: _handleConnectivityChipTap,
            onStorageTap: _handleStorageChipTap,
          ),
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
      nameController: _nameController,
      baseUrlController: _baseUrlController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      clientSavePathController: _clientSavePathController,
      localRootPathController: _localRootPathController,
      mediaLibraryId: _selectedLibraryId,
    );

    try {
      final api = context.read<DownloadClientsApi>();
      final client =
          _isEditing
              ? await api.updateClient(
                clientId: widget.initialClient!.id,
                payload: value.toUpdatePayload(),
              )
              : await api.createClient(value.toCreatePayload());
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
    final api = context.read<DownloadClientsApi>();
    await handleProbeConnectivityTap(
      context: context,
      probe: _probe,
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
    final api = context.read<DownloadClientsApi>();
    await handleProbeStorageTap(
      context: context,
      probe: _probe,
      runTest: () => api.probeStorageTestClient(payload),
      openDialog: (result) => _openStorageDialog(result, payload, value.baseUrl),
    );
  }

  Future<void> _openConnectivityDialog(
    DownloadClientTestResultDto result,
    DownloadClientProbeTestPayload payload,
  ) async {
    final api = context.read<DownloadClientsApi>();
    await showDialog<void>(
      context: context,
      builder: (_) => DownloadClientTestResultDialog(
        initialResult: result,
        onRerun: () => api.probeTestClient(payload),
        onResultChanged: _probe.applyConnectivityResult,
      ),
    );
  }

  Future<void> _openStorageDialog(
    DownloadClientStorageTestResultDto result,
    DownloadClientProbeStorageTestPayload payload,
    String baseUrl,
  ) async {
    final api = context.read<DownloadClientsApi>();
    await showDialog<void>(
      context: context,
      builder: (_) => DownloadClientStorageTestResultDialog(
        initialResult: result,
        clientBaseUrl: baseUrl,
        onRerun: () => api.probeStorageTestClient(payload),
        onResultChanged: _probe.applyStorageResult,
      ),
    );
  }
}

class _MobileDownloaderDetailDrawer extends StatefulWidget {
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
  State<_MobileDownloaderDetailDrawer> createState() =>
      _MobileDownloaderDetailDrawerState();
}

class _MobileDownloaderDetailDrawerState
    extends State<_MobileDownloaderDetailDrawer> {
  late final DownloadClientProbeController _probe;

  @override
  void initState() {
    super.initState();
    _probe = DownloadClientProbeController(
      connectivityChipState: widget.initialSnapshot.connectivityChipState,
      storageChipState: widget.initialSnapshot.storageChipState,
      connectivityResult: widget.initialSnapshot.connectivityResult,
      storageResult: widget.initialSnapshot.storageResult,
      onConnectivityChanged: widget.onConnectivityResult,
      onStorageChanged: widget.onStorageResult,
    )..addListener(_onProbeChanged);
  }

  @override
  void dispose() {
    _probe.removeListener(_onProbeChanged);
    _probe.dispose();
    super.dispose();
  }

  void _onProbeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleConnectivityAction() {
    final api = context.read<DownloadClientsApi>();
    return handleProbeConnectivityTap(
      context: context,
      probe: _probe,
      runTest: () => api.testClient(widget.client.id),
      openDialog: _openConnectivityDialog,
    );
  }

  Future<void> _handleStorageAction() {
    final api = context.read<DownloadClientsApi>();
    return handleProbeStorageTap(
      context: context,
      probe: _probe,
      runTest: () => api.storageTestClient(widget.client.id),
      openDialog: _openStorageDialog,
    );
  }

  Future<void> _openConnectivityDialog(
    DownloadClientTestResultDto result,
  ) async {
    final api = context.read<DownloadClientsApi>();
    await showDialog<void>(
      context: context,
      builder: (_) => DownloadClientTestResultDialog(
        initialResult: result,
        onRerun: () => api.testClient(widget.client.id),
        onResultChanged: _probe.applyConnectivityResult,
      ),
    );
  }

  Future<void> _openStorageDialog(
    DownloadClientStorageTestResultDto result,
  ) async {
    final api = context.read<DownloadClientsApi>();
    await showDialog<void>(
      context: context,
      builder: (_) => DownloadClientStorageTestResultDialog(
        initialResult: result,
        clientBaseUrl: widget.client.baseUrl,
        onRerun: () => api.storageTestClient(widget.client.id),
        onResultChanged: _probe.applyStorageResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final client = widget.client;
    final mediaLibrary = widget.mediaLibrary;
    final passwordLabel = client.hasPassword ? '已保存密码' : '待补密码';
    final busy = _probe.busy;

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
                      client.baseUrl,
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
                    client.hasPassword
                        ? AppBadgeTone.success
                        : AppBadgeTone.warning,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          AppInfoBlock(label: '用户名', value: client.username),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: '目标媒体库',
            value: mediaLibrary?.name ?? '未关联媒体库',
          ),
          SizedBox(height: spacing.sm),
          AppInfoBlock(
            label: 'qBittorrent保存路径',
            value: client.clientSavePath,
          ),
          SizedBox(height: spacing.sm),
          AppInfoBlock(label: '本地访问路径', value: client.localRootPath),
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
              DownloadClientProbeStatusChip(
                key: const Key('mobile-downloader-detail-probe-test-button'),
                label: '连通性',
                state: _probe.connectivityChipState,
                detail: _probe.connectivityChipDetail(),
                onTap: busy ? null : _handleConnectivityAction,
              ),
              DownloadClientProbeStatusChip(
                key: const Key(
                  'mobile-downloader-detail-probe-storage-test-button',
                ),
                label: '目录映射',
                state: _probe.storageChipState,
                detail: _probe.storageChipDetail(),
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

