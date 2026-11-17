import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/config/app_release_channels.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_feed_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/announcement_detail_dialog.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/shell/sidebar_version_footer.dart';

/// 账户卡版本入口的数据容器：读取版本、插件更新和前后端更新状态。
class SidebarVersionInfo extends ConsumerStatefulWidget {
  const SidebarVersionInfo({super.key, required this.onOpenPluginUpdates});

  final VoidCallback onOpenPluginUpdates;

  @override
  ConsumerState<SidebarVersionInfo> createState() => _SidebarVersionInfoState();
}

class _SidebarVersionInfoState extends ConsumerState<SidebarVersionInfo> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (_, next) {
      if (next && _menuOpen) {
        _menuOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });

    final version =
        ref.watch(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
    final pluginUpdates = ref.watch(pluginsProvider).value?.updates.length ?? 0;
    final updates = ref.watch(appUpdateCheckProvider);
    final announcements = ref.watch(announcementFeedProvider);

    return SidebarVersionFooter(
      version: version,
      pluginUpdates: pluginUpdates,
      updates: updates,
      announcements: announcements.active,
      hasUnseenAnnouncements: announcements.hasUnseen,
      onOpenAnnouncement: (announcement) =>
          unawaited(_openAnnouncement(context, announcement)),
      onOpenFrontendRelease: () => unawaited(
        _openRelease(context, ref, AppReleaseChannels.frontendPageUrl),
      ),
      onOpenBackendRelease: () => unawaited(
        _openRelease(context, ref, AppReleaseChannels.backendPageUrl),
      ),
      onOpenPluginUpdates: widget.onOpenPluginUpdates,
      onMenuOpened: () {
        _menuOpen = true;
        unawaited(ref.read(announcementFeedProvider.notifier).markSeen());
      },
      onMenuClosed: () => _menuOpen = false,
    );
  }
}

Future<void> _openAnnouncement(
  BuildContext context,
  AnnouncementDto announcement,
) async {
  await showAnnouncementDetailDialog(
    context: context,
    announcement: announcement,
  );
}

Future<void> _openRelease(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  final l10n = appL10n(context);
  final opened = await ref.read(externalUrlOpenerProvider)(uri);
  if (opened || !context.mounted) {
    return;
  }
  final copied = await copyTextToClipboard(url);
  if (!context.mounted) {
    return;
  }
  showToast(
    copied ? l10n.shellBrowserOpenFailedCopied : l10n.shellBrowserOpenFailed,
    tone: AppToastTone.error,
  );
}
