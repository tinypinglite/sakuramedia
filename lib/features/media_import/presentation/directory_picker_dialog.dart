import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_library_selector_field.dart';

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
  SourceDisposition _sourceDisposition = SourceDisposition.keep;

  bool get _canSubmit => _selectedLibrary != null && _source != null;

  void _handleLibraryChanged(MediaLibraryDto? library) {
    setState(() {
      _selectedLibrary = library;
      _source = null;
      _sourceDisposition = SourceDisposition.keep;
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
        sourceDisposition: _sourceDisposition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SingleChildScrollView(
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
              sourceDisposition: _sourceDisposition,
              onSourceChanged: (source) {
                if (source == _source) {
                  return;
                }
                setState(() => _source = source);
              },
              onSourceDispositionChanged: (disposition) {
                if (disposition == _sourceDisposition) {
                  return;
                }
                setState(() => _sourceDisposition = disposition);
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
                  label: '开始导入',
                  variant: AppButtonVariant.primary,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
