import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_form.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

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
                _MobileDownloadersOverviewCard(
                  clientCount: _clients.length,
                  linkedLibraryCount: _linkedLibraryCount,
                  savedPasswordCount: _savedPasswordCount,
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
                _MobileGuideStepCard(
                  key: const Key('mobile-downloaders-guide-step-libraries'),
                  title: '先准备媒体库',
                  description: '媒体库用于维护本地存储根路径，下载器创建前需要先明确映射位置。',
                  tip: '关键字段：媒体库名称、根路径。',
                  completed: _hasLibraries,
                  actionLabel: '前往媒体库',
                  onActionTap:
                      () => GoRouter.of(
                        context,
                      ).push(mobileSettingsMediaLibrariesPath),
                ),
                SizedBox(height: spacing.md),
                _MobileGuideStepCard(
                  key: const Key('mobile-downloaders-guide-step-downloaders'),
                  title: '再配置下载器',
                  description: '下载器负责接收索引器推送的资源请求，并映射 qBittorrent 下载路径。',
                  tip: '关键字段：服务地址、qBittorrent 保存路径、本地访问路径。',
                  completed: _clients.isNotEmpty,
                  actionLabel: '切换到下载器',
                  onActionTap: () => _tabController.animateTo(0),
                ),
                SizedBox(height: spacing.md),
                _MobileGuideStepCard(
                  key: const Key('mobile-downloaders-guide-step-indexers'),
                  title: '最后把索引器绑定到下载器',
                  description: '只有索引器绑定到下载器，影片详情里的资源搜索结果才能投递到对应客户端。',
                  tip: '常见问题：未绑定下载器时，搜索结果会提示先创建下载器。',
                  completed: _hasLinkedIndexer,
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
      return _MobileDownloadersErrorSection(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }
    if (_clients.isEmpty) {
      return const _MobileDownloadersEmptySection();
    }

    final librariesById = <int, MediaLibraryDto>{
      for (final library in _libraries) library.id: library,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _clients
          .expand(
            (client) => <Widget>[
              _MobileDownloaderCard(
                client: client,
                mediaLibrary: librariesById[client.mediaLibraryId],
                onTap: () => _handleShowDetail(client),
              ),
              if (client != _clients.last)
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
    final deletedClientId = await showMobileDeleteDownloaderDrawer(
      context,
      client: client,
    );
    if (!mounted || deletedClientId == null) {
      return;
    }
    setState(() {
      _clients = _clients
          .where((item) => item.id != deletedClientId)
          .toList(growable: false);
      _errorMessage = null;
    });
    unawaited(_syncDataInBackground());
  }

  Future<void> _handleShowDetail(DownloadClientDto client) async {
    final detailAction = await showMobileDownloaderDetailDrawer(
      context,
      client: client,
      mediaLibrary: _libraryById(client.mediaLibraryId),
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

Future<MobileDownloaderDetailAction?> showMobileDownloaderDetailDrawer(
  BuildContext context, {
  required DownloadClientDto client,
  required MediaLibraryDto? mediaLibrary,
}) {
  return showAppBottomDrawer<MobileDownloaderDetailAction>(
    context: context,
    drawerKey: const Key('mobile-downloader-detail-drawer'),
    heightFactor: 0.62,
    builder: (drawerContext) {
      return _MobileDownloaderDetailDrawer(
        client: client,
        mediaLibrary: mediaLibrary,
      );
    },
  );
}

Future<int?> showMobileDeleteDownloaderDrawer(
  BuildContext context, {
  required DownloadClientDto client,
}) {
  return showAppBottomDrawer<int>(
    context: context,
    drawerKey: const Key('mobile-downloader-delete-drawer'),
    maxHeightFactor: 0.42,
    builder: (drawerContext) {
      return _MobileDeleteDownloaderDrawer(client: client);
    },
  );
}

enum MobileDownloaderDetailAction { edit, delete }

class _MobileDownloadersOverviewCard extends StatelessWidget {
  const _MobileDownloadersOverviewCard({
    required this.clientCount,
    required this.linkedLibraryCount,
    required this.savedPasswordCount,
  });

  final int clientCount;
  final int linkedLibraryCount;
  final int savedPasswordCount;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-downloaders-overview-card'),
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
            '下载器负责接收索引器推送的资源请求，并依赖媒体库路径映射完成落库。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '建议先确认媒体库路径，再补全 qBittorrent 保存路径与本地访问路径。',
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
              Expanded(
                child: _OverviewStatBlock(
                  label: '已配置下载器数',
                  value: '$clientCount',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _OverviewStatBlock(
                  label: '关联媒体库数',
                  value: '$linkedLibraryCount',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _OverviewStatBlock(
                  label: '已保存密码数',
                  value: '$savedPasswordCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStatBlock extends StatelessWidget {
  const _OverviewStatBlock({required this.label, required this.value});

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
              size: AppTextSize.s18,
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

class _MobileDownloaderCard extends StatelessWidget {
  const _MobileDownloaderCard({
    required this.client,
    required this.mediaLibrary,
    required this.onTap,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final passwordTone =
        client.hasPassword ? AppBadgeTone.success : AppBadgeTone.warning;
    final passwordLabel = client.hasPassword ? '已保存密码' : '待补密码';

    return Container(
      key: Key('mobile-downloader-card-${client.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('mobile-downloader-card-body-${client.id}'),
          borderRadius: context.appRadius.lgBorder,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: context.appComponentTokens.iconSizeXl + spacing.md,
                  height: context.appComponentTokens.iconSizeXl + spacing.md,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: context.appRadius.mdBorder,
                  ),
                  child: Icon(
                    Icons.download_for_offline_outlined,
                    size: context.appComponentTokens.iconSizeMd,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
                              client.name,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                weight: AppTextWeight.semibold,
                                tone: AppTextTone.primary,
                              ),
                            ),
                          ),
                          SizedBox(width: spacing.sm),
                          AppBadge(
                            label: passwordLabel,
                            tone: passwordTone,
                            size: AppBadgeSize.compact,
                          ),
                        ],
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
                      _DownloaderMetaLine(
                        label: '本地访问路径',
                        value: client.localRootPath,
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        '更新时间: ${_formatUpdatedAt(client.updatedAt)}',
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
              ],
            ),
          ),
        ),
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
          _SkeletonBlock(
            width: context.appComponentTokens.iconSizeXl + spacing.md,
            height: context.appComponentTokens.iconSizeXl + spacing.md,
            radius: context.appRadius.md,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBlock(width: 116, height: 16),
                SizedBox(height: spacing.xs),
                const _SkeletonBlock(width: 188, height: 12),
                SizedBox(height: spacing.sm),
                const _SkeletonBlock(width: 132, height: 12),
                SizedBox(height: spacing.xs),
                const _SkeletonBlock(width: 168, height: 12),
                SizedBox(height: spacing.xs),
                const _SkeletonBlock(width: 148, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDownloadersErrorSection extends StatelessWidget {
  const _MobileDownloadersErrorSection({
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
      key: const Key('mobile-downloaders-error-state'),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(message: '下载器加载失败'),
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
              key: const Key('mobile-downloaders-retry-button'),
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

class _MobileDownloadersEmptySection extends StatelessWidget {
  const _MobileDownloadersEmptySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-downloaders-empty-state'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: const AppEmptyState(message: '还没有下载器配置'),
    );
  }
}

class _MobileGuideStepCard extends StatelessWidget {
  const _MobileGuideStepCard({
    super.key,
    required this.title,
    required this.description,
    required this.tip,
    required this.completed,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String description;
  final String tip;
  final bool completed;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final badgeTone = completed ? AppBadgeTone.success : AppBadgeTone.warning;
    final badgeLabel = completed ? '已配置' : '待配置';

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppBadge(
                label: badgeLabel,
                tone: badgeTone,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.sm),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Text(
              tip,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          AppButton(
            label: actionLabel,
            size: AppButtonSize.xSmall,
            onPressed: onActionTap,
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

  bool get _isEditing => widget.initialClient != null;

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
                _isEditing ? '编辑下载器' : '新增下载器',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                '维护下载器服务地址、路径映射和媒体库绑定关系。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
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
                enabled: !_isSubmitting,
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
                      key: const Key('mobile-downloader-submit-button'),
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
}

class _MobileDownloaderDetailDrawer extends StatelessWidget {
  const _MobileDownloaderDetailDrawer({
    required this.client,
    required this.mediaLibrary,
  });

  final DownloadClientDto client;
  final MediaLibraryDto? mediaLibrary;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final passwordLabel = client.hasPassword ? '已保存密码' : '待补密码';

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
          _DetailInfoBlock(label: '用户名', value: client.username),
          SizedBox(height: spacing.sm),
          _DetailInfoBlock(
            label: '目标媒体库',
            value: mediaLibrary?.name ?? '未关联媒体库',
          ),
          SizedBox(height: spacing.sm),
          _DetailInfoBlock(
            label: 'qBittorrent保存路径',
            value: client.clientSavePath,
          ),
          SizedBox(height: spacing.sm),
          _DetailInfoBlock(label: '本地访问路径', value: client.localRootPath),
          SizedBox(height: spacing.sm),
          _DetailInfoBlock(
            label: '更新时间',
            value: _formatUpdatedAt(client.updatedAt),
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
                      () => Navigator.of(
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
                      () => Navigator.of(
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

class _DetailInfoBlock extends StatelessWidget {
  const _DetailInfoBlock({required this.label, required this.value});

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

class _MobileDeleteDownloaderDrawer extends StatefulWidget {
  const _MobileDeleteDownloaderDrawer({required this.client});

  final DownloadClientDto client;

  @override
  State<_MobileDeleteDownloaderDrawer> createState() =>
      _MobileDeleteDownloaderDrawerState();
}

class _MobileDeleteDownloaderDrawerState
    extends State<_MobileDeleteDownloaderDrawer> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '删除下载器',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '确认删除下载器“${widget.client.name}”？该操作不会删除已有下载任务，但索引器绑定关系可能需要重新调整。',
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
                key: const Key('mobile-downloader-delete-confirm-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                isLoading: _isSubmitting,
                onPressed: _deleteClient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteClient() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<DownloadClientsApi>().deleteClient(widget.client.id);
      if (!mounted) {
        return;
      }
      showToast('下载器已删除');
      Navigator.of(context).pop(widget.client.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '删除下载器失败'));
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _formatUpdatedAt(DateTime? value) {
  if (value == null) {
    return '未知';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}
