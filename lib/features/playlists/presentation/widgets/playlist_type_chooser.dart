import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 新建播放列表前的类型选择：普通列表 / 智能列表。
///
/// 返回 null 表示用户放弃创建。
Future<String?> showPlaylistTypeChooser(BuildContext context) {
  return showAppAdaptiveModal<String>(
    context: context,
    modalKey: const Key('playlist-type-chooser-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthSm,
    builder: (_) => const PlaylistTypeChooser(),
  );
}

class PlaylistTypeChooser extends StatelessWidget {
  const PlaylistTypeChooser({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.playlistCreateTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          _PlaylistTypeOption(
            key: const Key('playlist-type-custom'),
            icon: Icons.playlist_add_rounded,
            title: l10n.playlistTypeCustomTitle,
            description: l10n.playlistTypeCustomDescription,
            onTap: () => Navigator.of(context).pop(PlaylistKind.custom),
          ),
          SizedBox(height: spacing.sm),
          _PlaylistTypeOption(
            key: const Key('playlist-type-smart'),
            icon: Icons.auto_awesome_rounded,
            title: l10n.playlistTypeSmartTitle,
            description: l10n.playlistTypeSmartDescription,
            onTap: () => Navigator.of(context).pop(PlaylistKind.smart),
          ),
          SizedBox(height: spacing.lg),
        ],
      ),
    );
  }
}

class _PlaylistTypeOption extends StatelessWidget {
  const _PlaylistTypeOption({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final radius = context.appRadius.mdBorder;
    return AppInteractiveSurface(
      onTap: onTap,
      focusRingRadius: radius,
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: radius,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: tokens.iconSizeMd,
              color: context.appTextPalette.secondary,
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    description,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: tokens.iconSizeMd,
              color: context.appTextPalette.muted,
            ),
          ],
        ),
      ),
    );
  }
}
