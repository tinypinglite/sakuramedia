import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 选择本次播放使用的外部播放器；取消时返回 null。
Future<ExternalPlayerApp?> showExternalPlayerPicker(BuildContext context) {
  return showAppAdaptiveModal<ExternalPlayerApp>(
    context: context,
    dialogKey: const Key('external-player-picker-dialog'),
    drawerKey: const Key('external-player-picker-drawer'),
    desktopWidth: 420,
    desktopHeight: 340,
    mobileHeightFactor: 0.45,
    builder: (_) => const ExternalPlayerPickerBody(),
  );
}

class ExternalPlayerPickerBody extends ConsumerStatefulWidget {
  const ExternalPlayerPickerBody({super.key});

  @override
  ConsumerState<ExternalPlayerPickerBody> createState() =>
      _ExternalPlayerPickerBodyState();
}

class _ExternalPlayerPickerBodyState
    extends ConsumerState<ExternalPlayerPickerBody> {
  List<ExternalPlayerApp> _players = const <ExternalPlayerApp>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlayers());
  }

  Future<void> _loadPlayers() async {
    setState(() => _isLoading = true);
    final baseUrl = ref.read(sessionStoreProvider).baseUrl;
    final players = await const ExternalPlayerChannel().listPlayers(
      sampleUrl: baseUrl.isEmpty ? null : baseUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _players = players;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.movieActionPlayExternal,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            if (!AppAdaptiveModalShellScope.maybeIsDrawer(context))
              SizedBox(width: spacing.xl),
            AppTextButton(
              key: const Key('external-player-picker-rescan'),
              label: l10n.externalPlayerRescan,
              size: AppTextButtonSize.small,
              onPressed: _isLoading ? null : () => unawaited(_loadPlayers()),
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        Text(
          l10n.movieActionExternalPlayerPickerHint,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.md),
        Expanded(child: _buildBody(context, l10n)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: AppInlineSpinner());
    }
    if (_players.isEmpty) {
      return AppEmptyState(
        icon: Icons.video_library_outlined,
        title: l10n.externalPlayerNoneFound,
        message: l10n.externalPlayerNoneFoundSubtitle,
        variant: AppStatePanelVariant.section,
      );
    }
    return SingleChildScrollView(
      child: AppSettingsGroup(
        children: <Widget>[
          for (final player in _players)
            AppSettingCell(
              key: Key('external-player-picker-${player.id}'),
              icon: Icons.play_circle_outline_rounded,
              title: player.label,
              onTap: () => Navigator.of(context).pop(player),
            ),
        ],
      ),
    );
  }
}
