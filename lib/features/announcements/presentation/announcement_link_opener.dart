import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

Future<void> openAnnouncementLink(
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
