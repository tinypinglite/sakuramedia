import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_dialog_shell.dart';

class MediaImportRequest {
  const MediaImportRequest({
    required this.libraryId,
    required this.source,
    required this.sourceDisposition,
  });

  final int libraryId;
  final MediaImportSource source;
  final SourceDisposition sourceDisposition;
}

Future<MediaImportRequest?> showDirectoryPickerDialog(BuildContext context) {
  return showAppAdaptiveModal<MediaImportRequest>(
    context: context,
    modalKey: const Key('media-import-directory-picker-modal'),
    desktopHeight: 640,
    builder: (_) => const DirectoryPickerDialog(),
  );
}

/// JAV 目录导入弹窗；表单结构复用 [MediaImportDialogShell]。
class DirectoryPickerDialog extends StatelessWidget {
  const DirectoryPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MediaImportDialogShell(
      title: l10n.mediaImportPickerTitle,
      submitLabel: l10n.mediaImportPickerSubmitAction,
      cancelKey: const Key('media-import-picker-cancel-button'),
      submitKey: const Key('media-import-picker-submit-button'),
      onSubmit: (submission) {
        Navigator.of(context).pop(
          MediaImportRequest(
            libraryId: submission.library.id,
            source: submission.source,
            sourceDisposition: submission.disposition,
          ),
        );
      },
    );
  }
}
