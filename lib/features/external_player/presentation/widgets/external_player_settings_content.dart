import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

/// 外部播放器设置的共用内容；移动与桌面使用同一份选择和持久化逻辑。
class ExternalPlayerSettingsContent extends ConsumerStatefulWidget {
  const ExternalPlayerSettingsContent({super.key, this.active = true});

  final bool active;

  @override
  ConsumerState<ExternalPlayerSettingsContent> createState() =>
      _ExternalPlayerSettingsContentState();
}

class _ExternalPlayerSettingsContentState
    extends ConsumerState<ExternalPlayerSettingsContent> {
  List<ExternalPlayerApp> _players = const <ExternalPlayerApp>[];
  bool _isLoading = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadIfActive();
  }

  @override
  void didUpdateWidget(covariant ExternalPlayerSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadIfActive();
  }

  void _loadIfActive() {
    if (!widget.active || _initialized) {
      return;
    }
    _initialized = true;
    unawaited(_loadPlayers());
  }

  Future<void> _loadPlayers() async {
    const channel = ExternalPlayerChannel();
    final baseUrl = ref.read(sessionStoreProvider).baseUrl;
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

  Future<void> _selectInApp() {
    return ref.read(externalPlayerPreferenceProvider.notifier).useInAppPlayer();
  }

  Future<void> _selectPlayer(ExternalPlayerApp player) {
    return ref
        .read(externalPlayerPreferenceProvider.notifier)
        .selectExternalPlayer(playerId: player.id, label: player.label);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox.shrink();
    }

    final spacing = context.appSpacing;
    // 读盘中 selection 为 null → 勾在「应用内播放器」上，与旧行为一致。
    final selection = ref.watch(externalPlayerPreferenceProvider).value;
    final selectedPlayerId = selection?.playerId;

    final cells = <Widget>[
      AppSettingCell(
        key: const Key('external-player-in-app'),
        icon: Icons.phonelink_ring_outlined,
        title: '应用内播放器',
        subtitle: '使用樱视内置播放器',
        trailing: selectedPlayerId == null ? const _SelectionCheckMark() : null,
        onTap: () => unawaited(_selectInApp()),
      ),
      for (final player in _players)
        AppSettingCell(
          key: Key('external-player-${player.id}'),
          icon: Icons.ondemand_video_outlined,
          title: player.label,
          trailing: selectedPlayerId == player.id
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            '未检测到可用的外部播放器。请先安装支持网络视频播放的播放器。',
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
