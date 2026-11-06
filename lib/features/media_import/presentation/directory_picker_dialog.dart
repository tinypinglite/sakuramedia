import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
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
    desktopHeight: 640,
    builder: (_) => const _DirectoryPickerDialog(),
  );
}

class _DirectoryPickerDialog extends ConsumerStatefulWidget {
  const _DirectoryPickerDialog();

  @override
  ConsumerState<_DirectoryPickerDialog> createState() =>
      _DirectoryPickerDialogState();
}

class _DirectoryPickerDialogState
    extends ConsumerState<_DirectoryPickerDialog> {
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
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final isInitialLoading =
        librariesAsync.isLoading && !librariesAsync.hasValue;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mediaImportPickerTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          Expanded(
            child: isInitialLoading
                ? const Center(child: AppPickerIosState(loading: true))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
          ),
          SizedBox(height: spacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('media-import-picker-cancel-button'),
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('media-import-picker-submit-button'),
                  label: l10n.mediaImportPickerSubmitAction,
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
