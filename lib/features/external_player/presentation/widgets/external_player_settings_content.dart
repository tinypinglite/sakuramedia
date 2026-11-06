import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_playback_mode.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
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
    setState(() => _isLoading = true);
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
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(externalPlayerPreferenceProvider).value;
    final selectedPlayerId = selection?.playerId;
    final playbackMode =
        selection?.playbackMode ?? ExternalPlaybackMode.followBackend;

    final cells = <Widget>[
      AppSettingCell(
        key: const Key('external-player-in-app'),
        icon: Icons.phonelink_ring_outlined,
        title: l10n.externalPlayerInAppTitle,
        subtitle: l10n.externalPlayerInAppSubtitle,
        trailing: selectedPlayerId == null ? const _SelectionCheckMark() : null,
        onTap: selection == null ? null : () => unawaited(_selectInApp()),
      ),
      for (final player in _players)
        AppSettingCell(
          key: Key('external-player-${player.id}'),
          icon: Icons.ondemand_video_outlined,
          title: player.label,
          trailing: selectedPlayerId == player.id
              ? const _SelectionCheckMark()
              : null,
          onTap: selection == null
              ? null
              : () => unawaited(_selectPlayer(player)),
        ),
      if (_isLoading)
        AppSettingCell(
          title: l10n.externalPlayerDetecting,
          trailing: const AppInlineSpinner(),
        ),
      if (!_isLoading && _players.isEmpty)
        AppSettingCell(
          icon: Icons.video_library_outlined,
          title: l10n.externalPlayerNoneFound,
          subtitle: l10n.externalPlayerNoneFoundSubtitle,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.externalPlayerIntro,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.externalPlayerDefaultPlayer,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                ),
              ),
            ),
            AppTextButton(
              key: const Key('external-player-refresh'),
              label: l10n.externalPlayerRescan,
              size: AppTextButtonSize.small,
              onPressed: _isLoading ? null : () => unawaited(_loadPlayers()),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        AppSettingsGroup(
          footer: l10n.externalPlayerGroupFooter,
          children: cells,
        ),
        SizedBox(height: spacing.xl),
        Text(
          l10n.externalPlayerPlaybackMode,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: spacing.sm),
        RadioGroup<ExternalPlaybackMode>(
          groupValue: playbackMode,
          onChanged: (mode) {
            if (mode == null || selection == null) return;
            unawaited(
              ref
                  .read(externalPlayerPreferenceProvider.notifier)
                  .selectPlaybackMode(mode),
            );
          },
          child: AppSettingsGroup(
            footer: l10n.externalPlayerModeFooter,
            children: [
              for (final mode in ExternalPlaybackMode.values)
                _PlaybackModeOption(
                  key: Key('external-playback-mode-${mode.name}'),
                  mode: mode,
                  selected: mode == playbackMode,
                  enabled: selection != null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackModeOption extends StatelessWidget {
  const _PlaybackModeOption({
    super.key,
    required this.mode,
    required this.selected,
    required this.enabled,
  });

  final ExternalPlaybackMode mode;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final (title, description) = switch (mode) {
      ExternalPlaybackMode.followBackend => (
        l10n.externalPlayerModeFollowBackendTitle,
        l10n.externalPlayerModeFollowBackendDescription,
      ),
      ExternalPlaybackMode.proxy => (
        l10n.externalPlayerModeProxyTitle,
        l10n.externalPlayerModeProxyDescription,
      ),
      ExternalPlaybackMode.redirect => (
        l10n.externalPlayerModeRedirectTitle,
        l10n.externalPlayerModeRedirectDescription,
      ),
    };
    return Material(
      color: Colors.transparent,
      child: RadioListTile<ExternalPlaybackMode>(
        value: mode,
        enabled: enabled,
        selected: selected,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.xs,
        ),
        title: Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
            tone: selected ? AppTextTone.accent : AppTextTone.primary,
          ),
        ),
        subtitle: Text(
          description,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ),
    );
  }
}

class _SelectionCheckMark extends StatelessWidget {
  const _SelectionCheckMark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_rounded,
      size: context.appComponentTokens.iconSizeMd,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
