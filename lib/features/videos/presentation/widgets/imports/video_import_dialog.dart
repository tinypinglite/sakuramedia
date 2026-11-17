import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_single_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/video_collection_picker_field.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_editor_dialog.dart';
import 'package:sakuramedia/widgets/domain/media_import/media_import_dialog_shell.dart';

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
///
/// 跨域公共入口：媒体导入页通过 [videoImportDialogs] 复用本弹窗，
/// 不要直引本文件私有路径。
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
          ? CollectionEditorPresentation.bottomFormSheet
          : CollectionEditorPresentation.dialog,
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

  @override
  Widget build(BuildContext context) {
    // 维持合集 overview 存活：嵌套的单选弹层复用同一份缓存，不重复全量拉取。
    ref.listen(videoCollectionsOverviewProvider, (_, _) {});
    final l10n = AppLocalizations.of(context);
    return MediaImportDialogShell(
      title: l10n.videoImportTitle,
      submitLabel: l10n.videoImportStart,
      submitKey: const Key('video-import-submit-button'),
      allowFileSource: true,
      browserHeight: _videoImportBrowserHeight,
      extraFieldBuilder: (context, _) => _buildCollectionField(context),
      onSubmit: (submission) {
        Navigator.of(context).pop(
          VideoImportRequest(
            libraryId: submission.library.id,
            source: submission.source,
            sourceDisposition: submission.disposition,
            collectionId: _collectionId,
          ),
        );
      },
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
