import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/account_security_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/advanced_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_clients_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_selection_policy_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/indexer_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/media_libraries_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/media_tags_section.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/system_maintenance_section.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/appearance_settings_content.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/blacklisted_movies_section.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugins_section.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_rail.dart';

class DesktopConfigurationPage extends ConsumerStatefulWidget {
  const DesktopConfigurationPage({super.key});

  @override
  ConsumerState<DesktopConfigurationPage> createState() =>
      _DesktopConfigurationPageState();
}

class _DesktopConfigurationPageState
    extends ConsumerState<DesktopConfigurationPage> {
  static const Key _defaultCategoryKey = Key(
    'configuration-tab-media-libraries',
  );
  static const Key _downloadSelectionCategoryKey = Key(
    'configuration-tab-download-selection',
  );
  static const Key _advancedCategoryKey = Key('configuration-tab-advanced');

  List<_ConfigurationTab> get _tabs => _buildTabs(AppLocalizations.of(context));
  int _selectedIndex = 2;
  final Set<Key> _dirtyTabs = <Key>{};

  // 顺序即右侧 IndexedStack 的索引；itemKey 沿用原 tab key，保持深链/测试兼容。
  List<_ConfigurationTab> _buildTabs(AppLocalizations l10n) {
    return [
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-account-security'),
          label: l10n.configTabAccountSecurity,
          icon: Icons.shield_outlined,
        ),
        builder: (active) => AccountSecuritySection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-appearance'),
          label: l10n.configTabAppearance,
          icon: Icons.palette_outlined,
        ),
        builder: (active) => const AppearanceSettingsContent(),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: _defaultCategoryKey,
          label: l10n.configTabMediaLibraries,
          icon: Icons.folder_open_outlined,
        ),
        builder: (active) => MediaLibrariesSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-media-tags'),
          label: l10n.configTabMediaTags,
          icon: Icons.sell_outlined,
        ),
        builder: (active) => DesktopMediaTagsSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-downloads'),
          label: l10n.configTabDownloadClients,
          icon: Icons.download_outlined,
        ),
        builder: (active) => DownloadClientsSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-indexers'),
          label: l10n.configTabIndexers,
          icon: Icons.travel_explore_outlined,
        ),
        builder: (active) => IndexerSettingsSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: _downloadSelectionCategoryKey,
          label: l10n.configTabDownloadSelection,
          icon: Icons.filter_alt_outlined,
        ),
        selfScrolling: true,
        builder: (active) => DownloadSelectionPolicySection(
          active: active,
          onDirtyChanged: (dirty) =>
              _handleTabDirtyChanged(_downloadSelectionCategoryKey, dirty),
        ),
      ),
      if (const ExternalPlayerChannel().isSupported)
        _ConfigurationTab(
          category: _ConfigurationCategory(
            itemKey: const Key('configuration-tab-external-player'),
            label: l10n.configTabExternalPlayer,
            icon: Icons.open_in_new_rounded,
          ),
          builder: (active) => ExternalPlayerSettingsContent(active: active),
        ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-blacklisted-movies'),
          label: l10n.configTabBlacklistedMovies,
          icon: Icons.block_outlined,
        ),
        // 列表页自持滚动容器（滚到底加载下一页），不再套外层滚动视图。
        selfScrolling: true,
        builder: (active) => BlacklistedMoviesSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: _advancedCategoryKey,
          label: l10n.configTabAdvanced,
          icon: Icons.tune_outlined,
        ),
        builder: (active) => DesktopAdvancedSettingsSection(
          active: active,
          onDirtyChanged: (dirty) =>
              _handleTabDirtyChanged(_advancedCategoryKey, dirty),
        ),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-plugins'),
          label: l10n.configTabPlugins,
          icon: Icons.extension_outlined,
        ),
        builder: (active) => DesktopPluginsSection(active: active),
      ),
      _ConfigurationTab(
        category: _ConfigurationCategory(
          itemKey: const Key('configuration-tab-system-maintenance'),
          label: l10n.configTabSystemMaintenance,
          icon: Icons.build_outlined,
        ),
        builder: (active) => SystemMaintenanceSection(active: active),
      ),
      // 媒体维护 / 媒体管理已迁出：并入侧边栏「管理 > 媒体管理」独立页（三 tab）。
    ];
  }

  Future<void> _select(int index) async {
    if (_selectedIndex == index) {
      return;
    }
    final leavingKey = _tabs[_selectedIndex].category.itemKey;
    if (_dirtyTabs.contains(leavingKey)) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.configUnsavedChangesTitle,
        message: l10n.configLeaveUnsavedMessage,
        confirmLabel: l10n.configLeaveConfirm,
        dialogKey: const Key('configuration-advanced-leave-confirm-dialog'),
        confirmKey: const Key('configuration-advanced-leave-confirm-button'),
        cancelKey: const Key('configuration-advanced-leave-cancel-button'),
      );
      if (!confirmed || !mounted) {
        return;
      }
      if (leavingKey == _downloadSelectionCategoryKey) {
        ref.read(downloadSelectionPolicyProvider.notifier).discardDraft();
      }
    }
    setState(() {
      _dirtyTabs.remove(leavingKey);
      _selectedIndex = index;
    });
  }

  void _handleTabDirtyChanged(Key tabKey, bool dirty) {
    if (dirty == _dirtyTabs.contains(tabKey)) return;
    setState(() {
      if (dirty) {
        _dirtyTabs.add(tabKey);
      } else {
        _dirtyTabs.remove(tabKey);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _applyTabRequest(ref.read(configurationTabRequestProvider));
  }

  /// 消费「去修复」等入口留下的一次性跳转请求：切到对应分类后立即清空信号。
  void _applyTabRequest(String? tabKey) {
    if (tabKey == null) {
      return;
    }
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(configurationTabRequestProvider.notifier).clear();
      final index = _tabs.indexWhere(
        (tab) => tab.category.itemKey == Key(tabKey),
      );
      if (index >= 0) {
        unawaited(_select(index));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(configurationTabRequestProvider, (previous, next) {
      _applyTabRequest(next);
    });
    final spacing = context.appSpacing;
    return Row(
      key: const Key('configuration-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsRail(
          selectedIndex: _selectedIndex,
          onSelected: _select,
          items: [
            for (final tab in _tabs)
              AppSettingsRailItem(
                itemKey: tab.category.itemKey,
                label: tab.category.label,
                icon: tab.category.icon,
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
                  _tabs[_selectedIndex].category.label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
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
                    for (var i = 0; i < _tabs.length; i++)
                      if (_tabs[i].selfScrolling)
                        _tabs[i].builder(i == _selectedIndex)
                      else
                        _ConfigurationTabScrollView(
                          child: _tabs[i].builder(i == _selectedIndex),
                        ),
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

/// 系统设置单个分类页：分类描述 + 内容构建器。
class _ConfigurationTab {
  const _ConfigurationTab({
    required this.category,
    required this.builder,
    this.selfScrolling = false,
  });

  final _ConfigurationCategory category;
  final Widget Function(bool active) builder;

  /// 内容自带滚动容器（分页列表）时为 true，外层不再包 [_ConfigurationTabScrollView]。
  final bool selfScrolling;
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

class _ConfigurationTabScrollView extends StatelessWidget {
  const _ConfigurationTabScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          right: context.appSpacing.lg,
          bottom: context.appSpacing.xxl,
        ),
        child: child,
      ),
    );
  }
}
