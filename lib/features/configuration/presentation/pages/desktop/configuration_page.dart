import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/account_security_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/advanced_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/download_clients_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/indexer_settings_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/media_libraries_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/playlists_section.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/system_maintenance_section.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/blacklisted_movies_section.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugins_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_rail.dart';

class DesktopConfigurationPage extends StatefulWidget {
  const DesktopConfigurationPage({super.key});

  @override
  State<DesktopConfigurationPage> createState() =>
      _DesktopConfigurationPageState();
}

class _DesktopConfigurationPageState extends State<DesktopConfigurationPage> {
  static const Key _defaultCategoryKey = Key(
    'configuration-tab-media-libraries',
  );
  static const Key _advancedCategoryKey = Key('configuration-tab-advanced');

  late final List<_ConfigurationTab> _tabs = _buildTabs();
  late int _selectedIndex = _tabs.indexWhere(
    (tab) => tab.category.itemKey == _defaultCategoryKey,
  );
  bool _advancedSettingsDirty = false;

  // 顺序即右侧 IndexedStack 的索引；itemKey 沿用原 tab key，保持深链/测试兼容。
  List<_ConfigurationTab> _buildTabs() {
    return [
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-account-security'),
          label: '账号安全',
          icon: Icons.shield_outlined,
        ),
        builder: (active) => AccountSecuritySection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: _defaultCategoryKey,
          label: '媒体库',
          icon: Icons.folder_open_outlined,
        ),
        builder: (active) => MediaLibrariesSection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-downloads'),
          label: '下载器',
          icon: Icons.download_outlined,
        ),
        builder: (active) => DownloadClientsSection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-indexers'),
          label: '索引器',
          icon: Icons.travel_explore_outlined,
        ),
        builder: (active) => IndexerSettingsSection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-playlists'),
          label: '播放列表',
          icon: Icons.playlist_play_outlined,
        ),
        builder: (active) => PlaylistsSection(active: active),
      ),
      if (const ExternalPlayerChannel().isSupported)
        _ConfigurationTab(
          category: const _ConfigurationCategory(
            itemKey: Key('configuration-tab-external-player'),
            label: '外部播放器',
            icon: Icons.open_in_new_rounded,
          ),
          builder: (active) => ExternalPlayerSettingsContent(active: active),
        ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-blacklisted-movies'),
          label: '屏蔽影片',
          icon: Icons.block_outlined,
        ),
        builder: (active) => BlacklistedMoviesSection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: _advancedCategoryKey,
          label: '高级设置',
          icon: Icons.tune_outlined,
        ),
        builder: (active) => DesktopAdvancedSettingsSection(
          active: active,
          onDirtyChanged: _handleAdvancedDirtyChanged,
        ),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-plugins'),
          label: '插件',
          icon: Icons.extension_outlined,
        ),
        builder: (active) => DesktopPluginsSection(active: active),
      ),
      _ConfigurationTab(
        category: const _ConfigurationCategory(
          itemKey: Key('configuration-tab-system-maintenance'),
          label: '系统维护',
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
    final leavingAdvanced =
        _tabs[_selectedIndex].category.itemKey == _advancedCategoryKey;
    if (leavingAdvanced && _advancedSettingsDirty) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '有未保存的改动',
        message: '高级设置里还有未保存的改动，确认离开？',
        confirmLabel: '确认离开',
        dialogKey: const Key('configuration-advanced-leave-confirm-dialog'),
        confirmKey: const Key('configuration-advanced-leave-confirm-button'),
        cancelKey: const Key('configuration-advanced-leave-cancel-button'),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleAdvancedDirtyChanged(bool dirty) {
    if (_advancedSettingsDirty == dirty) {
      return;
    }
    setState(() {
      _advancedSettingsDirty = dirty;
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
                    for (var i = 0; i < _tabs.length; i++)
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
  const _ConfigurationTab({required this.category, required this.builder});

  final _ConfigurationCategory category;
  final Widget Function(bool active) builder;
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
