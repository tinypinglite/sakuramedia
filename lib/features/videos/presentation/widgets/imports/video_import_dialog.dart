import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_source_picker.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_library_selector_field.dart';

/// PornBox 视频导入的表单结果：来源可以是本地路径或 115 目录 CID；导入方式随来源类型联动。
class VideoImportRequest {
  const VideoImportRequest({
    required this.libraryId,
    required this.source,
    required this.transferMode,
    required this.collectionId,
  });

  final int libraryId;
  final MediaImportSource source;
  final TransferMode transferMode;
  final int collectionId;
}

/// 打开视频导入对话框；用户确认后返回 [VideoImportRequest]，取消返回 `null`。
Future<VideoImportRequest?> showVideoImportDialog(BuildContext context) {
  return showDialog<VideoImportRequest>(
    context: context,
    builder: (dialogContext) => const VideoImportDialog(),
  );
}

class VideoImportDialog extends StatefulWidget {
  const VideoImportDialog({super.key});

  @override
  State<VideoImportDialog> createState() => _VideoImportDialogState();
}

class _VideoImportDialogState extends State<VideoImportDialog> {
  MediaLibraryDto? _selectedLibrary;
  MediaImportSource? _source;
  TransferMode _transferMode = TransferMode.auto;

  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  int? _collectionId;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final collections =
          await context.read<VideoCollectionsApi>().getCollections();
      if (mounted) {
        setState(() => _collections = collections);
      }
    } catch (_) {
      // 合集加载失败不阻塞浏览，用户仍可现场「新建合集」后再导入。
    }
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(context);
    if (created == null || !mounted) {
      return;
    }
    setState(() {
      _collections = <VideoCollectionDto>[..._collections, created];
      _collectionId = created.id;
    });
  }

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
    if (source == null) {
      showToast('请先选择要导入的目录');
      return;
    }
    if (library == null) {
      showToast('请选择导入到的媒体库');
      return;
    }
    final collectionId = _collectionId;
    if (collectionId == null) {
      showToast('请选择或新建一个合集');
      return;
    }
    Navigator.of(context).pop(
      VideoImportRequest(
        libraryId: library.id,
        source: source,
        transferMode: _transferMode,
        collectionId: collectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final deletingCloudSource = _selectedLibrary?.isCloud115 == true &&
        _transferMode == TransferMode.cleanupSource;
    return AppDesktopDialog(
      width: context.appLayoutTokens.dialogWidthMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入 PornBox 视频',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
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
                  SizedBox(height: spacing.lg),
                  _buildCollectionField(context),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.xl),
          Row(
            children: [
              const Spacer(),
              AppButton(
                label: '取消',
                size: AppButtonSize.small,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: spacing.sm),
              AppButton(
                key: const Key('video-import-submit-button'),
                label: deletingCloudSource ? '导入并删除源文件' : '开始导入',
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '加入合集',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
            const Spacer(),
            AppTextButton(
              key: const Key('video-import-create-collection-button'),
              label: '新建合集',
              size: AppTextButtonSize.small,
              onPressed: _createCollection,
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.sm),
        AppSelectField<int?>(
          value: _collectionId,
          placeholder: _collections.isEmpty ? '暂无合集，点右上「新建合集」' : '请选择合集',
          items: <DropdownMenuItem<int?>>[
            for (final collection in _collections)
              DropdownMenuItem<int?>(
                value: collection.id,
                child: Text(collection.name),
              ),
          ],
          onChanged: (value) => setState(() => _collectionId = value),
        ),
      ],
    );
  }
}
