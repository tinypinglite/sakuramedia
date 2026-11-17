import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_library_selector_field.dart';

/// 导入弹窗共享表单壳：JAV 目录导入与视频导入的公共结构。
///
/// 壳接管媒体库选择、资源浏览、来源处置三块公共状态与加载态，
/// 调用方只提供标题、提交文案、视频合集等扩展字段与提交组装。
class MediaImportFormSubmission {
  const MediaImportFormSubmission({
    required this.library,
    required this.source,
    required this.disposition,
  });

  final MediaLibraryDto library;
  final MediaImportSource source;
  final SourceDisposition disposition;
}

class MediaImportDialogShell extends ConsumerStatefulWidget {
  const MediaImportDialogShell({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.submitKey,
    this.extraFieldBuilder,
    this.allowFileSource = false,
    this.browserHeight,
  });

  final String title;
  final String submitLabel;
  final ValueChanged<MediaImportFormSubmission> onSubmit;
  final Key? submitKey;

  /// 选中媒体库后的扩展字段（如视频合集选择器）；无选中库时不调用。
  final Widget Function(BuildContext context, MediaLibraryDto library)?
  extraFieldBuilder;

  final bool allowFileSource;
  final double? browserHeight;

  @override
  ConsumerState<MediaImportDialogShell> createState() =>
      _MediaImportDialogShellState();
}

class _MediaImportDialogShellState
    extends ConsumerState<MediaImportDialogShell> {
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
    widget.onSubmit(
      MediaImportFormSubmission(
        library: library,
        source: source,
        disposition: _sourceDisposition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final isInitialLoading =
        librariesAsync.isLoading && !librariesAsync.hasValue;
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final selectedLibrary = _selectedLibrary;
    final extraFieldBuilder = widget.extraFieldBuilder;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          Expanded(
            child: isInitialLoading
                ? const Center(child: AppPickerIosState(loading: true))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MediaLibrarySelectorField(
                          selectedLibraryId: _selectedLibrary?.id,
                          onLibraryChanged: _handleLibraryChanged,
                        ),
                        if (selectedLibrary != null) ...[
                          if (extraFieldBuilder != null) ...[
                            SizedBox(height: spacing.md),
                            extraFieldBuilder(context, selectedLibrary),
                          ],
                          SizedBox(height: spacing.md),
                          MediaImportSourcePicker(
                            selectedLibrary: selectedLibrary,
                            sourceDisposition: _sourceDisposition,
                            allowFileSource: widget.allowFileSource,
                            browserHeight: widget.browserHeight,
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
          AppModalActionRow(
            submitKey: widget.submitKey,
            submitLabel: widget.submitLabel,
            showCancel: false,
            equalWidth: isDrawer,
            submitDisabled: !_canSubmit,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}
