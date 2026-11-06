import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_single_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/video_collection_picker_field.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_library_selector_field.dart';

const _videoImportBrowserHeight = 220.0;

/// Provider-neutral 视频导入表单结果。
class VideoImportRequest {
  const VideoImportRequest({
    required this.libraryId,
    required this.source,
    required this.sourceDisposition,
    required this.collectionId,
  });

  final int libraryId;
  final MediaImportSource source;
  final SourceDisposition sourceDisposition;
  final int? collectionId;
}

/// 打开视频导入对话框；用户确认后返回 [VideoImportRequest]，取消返回 `null`。
Future<VideoImportRequest?> showVideoImportDialog(BuildContext context) {
  return showAppAdaptiveModal<VideoImportRequest>(
    context: context,
    modalKey: const Key('video-import-modal'),
    desktopHeight: (MediaQuery.sizeOf(context).height - 48).clamp(640.0, 760.0),
    builder: (_) => const VideoImportDialog(),
  );
}

class VideoImportDialog extends ConsumerStatefulWidget {
  const VideoImportDialog({super.key});

  @override
  ConsumerState<VideoImportDialog> createState() => _VideoImportDialogState();
}

class _VideoImportDialogState extends ConsumerState<VideoImportDialog> {
  MediaLibraryDto? _selectedLibrary;
  MediaImportSource? _source;
  SourceDisposition _sourceDisposition = SourceDisposition.keep;

  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  int? _collectionId;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      // 与合集列表页共用 overview 缓存，减少一次全量拉取。
      final collections = await ref.read(
        videoCollectionsOverviewProvider.future,
      );
      if (mounted) {
        setState(() => _collections = collections);
      }
    } catch (_) {
      // 合集加载失败不阻塞浏览，用户仍可现场「新建合集」后再导入。
    }
  }

  Future<void> _pickCollection() async {
    final result = await showPickVideoCollectionSingleDialog(
      context,
      selectedCollectionId: _collectionId,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _collectionId = result.collectionId);
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: AppPlatformScope.maybeOf(context) == AppPlatform.mobile
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() {
      _collections = <VideoCollectionDto>[..._collections, created];
      _collectionId = created.id;
    });
    // 同步 overview 缓存：其后打开的单选弹层复用同一份缓存，才不会漏掉刚建的合集。
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

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
      VideoImportRequest(
        libraryId: library.id,
        source: source,
        sourceDisposition: _sourceDisposition,
        collectionId: _collectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 维持合集 overview 存活：嵌套的单选弹层复用同一份缓存，不重复全量拉取。
    ref.listen(videoCollectionsOverviewProvider, (_, _) {});
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final isInitialLoading =
        librariesAsync.isLoading && !librariesAsync.hasValue;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.videoImportTitle,
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
                        if (_selectedLibrary != null) ...[
                          SizedBox(height: spacing.md),
                          _buildCollectionField(context),
                          SizedBox(height: spacing.md),
                          MediaImportSourcePicker(
                            selectedLibrary: _selectedLibrary,
                            sourceDisposition: _sourceDisposition,
                            allowFileSource: true,
                            browserHeight: _videoImportBrowserHeight,
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
                  label: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: AppButton(
                  key: const Key('video-import-submit-button'),
                  label: l10n.videoImportStart,
                  variant: AppButtonVariant.primary,
                  onPressed: _selectedLibrary != null && _source != null
                      ? _submit
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionField(BuildContext context) {
    String? selectedName;
    if (_collectionId != null) {
      selectedName = AppLocalizations.of(context).videoSelectedCollection;
      for (final collection in _collections) {
        if (collection.id == _collectionId) {
          selectedName = collection.name;
          break;
        }
      }
    }
    return VideoCollectionPickerField(
      valueLabel: selectedName,
      onTap: _pickCollection,
      onCreate: _createCollection,
      fieldKey: const Key('video-import-collection-field'),
      createButtonKey: const Key('video-import-create-collection-button'),
    );
  }
}
