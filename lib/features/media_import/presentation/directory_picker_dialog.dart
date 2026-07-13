import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_library_selector_field.dart';

class MediaImportRequest {
  const MediaImportRequest({
    required this.libraryId,
    required this.source,
    required this.transferMode,
  });

  final int libraryId;
  final MediaImportSource source;
  final TransferMode transferMode;
}

Future<MediaImportRequest?> showDirectoryPickerDialog(BuildContext context) {
  return showDialog<MediaImportRequest>(
    context: context,
    builder: (_) => const _DirectoryPickerDialog(),
  );
}

class _DirectoryPickerDialog extends StatefulWidget {
  const _DirectoryPickerDialog();

  @override
  State<_DirectoryPickerDialog> createState() => _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState extends State<_DirectoryPickerDialog> {
  MediaLibraryDto? _selectedLibrary;
  MediaImportSource? _source;
  TransferMode _transferMode = TransferMode.auto;

  bool get _isCloud115 => _selectedLibrary?.isCloud115 ?? false;

  bool get _canSubmit => _selectedLibrary != null && _source != null;

  void _handleLibraryChanged(MediaLibraryDto? library) {
    setState(() {
      _selectedLibrary = library;
      _source = null;
      _transferMode = library == null
          ? TransferMode.auto
          : MediaImportSourcePicker.defaultTransferModeFor(library);
    });
  }

  void _submit() {
    final library = _selectedLibrary;
    final source = _source;
    if (library == null || source == null) {
      return;
    }
    Navigator.of(context).pop(
      MediaImportRequest(
        libraryId: library.id,
        source: source,
        transferMode: _transferMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final deletingCloudSource =
        _isCloud115 && _transferMode == TransferMode.cleanupSource;
    return AppDesktopDialog(
      dialogKey: const Key('media-import-directory-picker-dialog'),
      width: context.appLayoutTokens.dialogWidthMd,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '新建媒体导入',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.md),
            MediaLibrarySelectorField(
              selectedLibraryId: _selectedLibrary?.id,
              onLibraryChanged: _handleLibraryChanged,
            ),
            if (_selectedLibrary != null) ...[
              SizedBox(height: spacing.md),
              MediaImportSourcePicker(
                selectedLibrary: _selectedLibrary,
                transferMode: _transferMode,
                onSourceChanged: (source) {
                  if (source == _source) {
                    return;
                  }
                  setState(() => _source = source);
                },
                onTransferModeChanged: (mode) {
                  if (mode == _transferMode) {
                    return;
                  }
                  setState(() => _transferMode = mode);
                },
              ),
            ],
            SizedBox(height: spacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('media-import-picker-cancel-button'),
                    label: '取消',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: const Key('media-import-picker-submit-button'),
                    label: deletingCloudSource ? '导入并删除源文件' : '开始导入',
                    variant: AppButtonVariant.primary,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
