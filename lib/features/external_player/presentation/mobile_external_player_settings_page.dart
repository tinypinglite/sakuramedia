import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class MobileExternalPlayerSettingsPage extends StatefulWidget {
  const MobileExternalPlayerSettingsPage({super.key});

  @override
  State<MobileExternalPlayerSettingsPage> createState() =>
      _MobileExternalPlayerSettingsPageState();
}

class _MobileExternalPlayerSettingsPageState
    extends State<MobileExternalPlayerSettingsPage> {
  List<ExternalPlayerApp> _players = const <ExternalPlayerApp>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlayers());
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoading = true;
    });
    const channel = ExternalPlayerChannel();
    final baseUrl = context.read<SessionStore>().baseUrl;
    final players = await channel.listPlayers(
      sampleUrl: baseUrl.isNotEmpty ? baseUrl : null,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _players = players;
      _isLoading = false;
    });
  }

  Future<void> _selectInApp() async {
    await context.read<ExternalPlayerStore>().useInAppPlayer();
  }

  Future<void> _selectPlayer(ExternalPlayerApp player) async {
    await context.read<ExternalPlayerStore>().selectExternalPlayer(
      packageName: player.packageName,
      label: player.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final store = context.watch<ExternalPlayerStore>();
    final selectedPackage = store.packageName;

    final cells = <Widget>[
      AppSettingCell(
        key: const Key('mobile-external-player-in-app'),
        icon: Icons.phonelink_ring_outlined,
        title: '应用内播放器',
        subtitle: '使用樱视内置播放器',
        trailing:
            selectedPackage == null ? const _SelectionCheckMark() : null,
        onTap: () => unawaited(_selectInApp()),
      ),
      for (final player in _players)
        AppSettingCell(
          key: Key('mobile-external-player-${player.packageName}'),
          icon: Icons.ondemand_video_outlined,
          title: player.label,
          trailing: selectedPackage == player.packageName
              ? const _SelectionCheckMark()
              : null,
          onTap: () => unawaited(_selectPlayer(player)),
        ),
      if (_isLoading)
        const AppSettingCell(
          title: '正在检测已安装的播放器…',
          trailing: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
    ];

    return ListView(
      key: const Key('mobile-external-player-settings'),
      children: [
        Text(
          '选择默认外部播放器后，点击播放将直接调用该播放器，不再进入应用内播放页。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(children: cells),
        if (!_isLoading && _players.isEmpty) ...[
          SizedBox(height: spacing.md),
          Text(
            '未检测到可用的外部播放器。请先在系统中安装支持视频播放的应用（如 VLC、MX Player）。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.tertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionCheckMark extends StatelessWidget {
  const _SelectionCheckMark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_rounded,
      size: 20,
      color: context.appColors.selectionBorder,
    );
  }
}
