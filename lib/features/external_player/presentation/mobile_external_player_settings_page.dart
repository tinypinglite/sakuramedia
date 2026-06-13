import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_store.dart';
import 'package:sakuramedia/theme.dart';

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
        _buildPlayerGroup(context, selectedPackage),
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

  Widget _buildPlayerGroup(BuildContext context, String? selectedPackage) {
    final rows = <Widget>[
      _SelectableRow(
        key: const Key('mobile-external-player-in-app'),
        icon: Icons.phonelink_ring_outlined,
        label: '应用内播放器',
        description: '使用樱视内置播放器',
        selected: selectedPackage == null,
        onTap: () => unawaited(_selectInApp()),
      ),
    ];

    for (final player in _players) {
      rows.add(
        _SelectableRow(
          key: Key('mobile-external-player-${player.packageName}'),
          icon: Icons.ondemand_video_outlined,
          label: player.label,
          selected: selectedPackage == player.packageName,
          onTap: () => unawaited(_selectPlayer(player)),
        ),
      );
    }

    if (_isLoading) {
      rows.add(const _PlayerLoadingRow());
    }

    final children = <Widget>[];
    for (var index = 0; index < rows.length; index++) {
      if (index > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: context.appColors.divider),
        );
      }
      children.add(rows[index]);
    }

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Material(
      color: selected ? colors.selectionSurface : colors.surfaceCard,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? colors.selectionBorder : colors.borderStrong,
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight:
                            selected
                                ? AppTextWeight.semibold
                                : AppTextWeight.medium,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (description != null) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        description!,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: colors.selectionBorder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerLoadingRow extends StatelessWidget {
  const _PlayerLoadingRow();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: spacing.md),
          Text(
            '正在检测已安装的播放器…',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
