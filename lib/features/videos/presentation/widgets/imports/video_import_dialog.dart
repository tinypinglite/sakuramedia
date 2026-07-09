import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// PornBox 视频导入的表单结果：浏览后端目录选取源路径，选定媒体库、合集（必选）与导入方式。
class VideoImportRequest {
  const VideoImportRequest({
    required this.libraryId,
    required this.sourcePath,
    required this.transferMode,
    required this.collectionId,
  });

  final int libraryId;
  final String sourcePath;
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
  late final MediaImportApi _filesystemApi;
  late final MediaLibrariesApi _librariesApi;

  FilesystemListResponseDto? _listing;
  bool _isBrowsing = true;
  String? _browseError;
  String? _sourcePath;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  int? _libraryId;
  TransferMode _transferMode = TransferMode.auto;

  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  int? _collectionId;

  @override
  void initState() {
    super.initState();
    _filesystemApi = context.read<MediaImportApi>();
    _librariesApi = context.read<MediaLibrariesApi>();
    _browse(null);
    _loadLibraries();
    _loadCollections();
  }

  Future<void> _browse(String? path) async {
    setState(() {
      _isBrowsing = true;
      _browseError = null;
    });
    try {
      final listing = await _filesystemApi.listEntries(path: path);
      if (!mounted) {
        return;
      }
      setState(() {
        _listing = listing;
        _isBrowsing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _browseError = apiErrorMessage(error, fallback: '目录浏览失败');
        _isBrowsing = false;
      });
    }
  }

  Future<void> _loadLibraries() async {
    try {
      final libraries = await _librariesApi.getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _libraryId ??= libraries.isNotEmpty ? libraries.first.id : null;
      });
    } catch (_) {
      // 媒体库加载失败时下拉为空，开始导入按钮校验时给出提示。
    }
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

  void _submit() {
    final sourcePath = _sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      showToast('请先选择要导入的目录或视频文件');
      return;
    }
    final libraryId = _libraryId;
    if (libraryId == null) {
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
        libraryId: libraryId,
        sourcePath: sourcePath,
        transferMode: _transferMode,
        collectionId: collectionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
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
                  _buildFieldLabel(context, '选择来源'),
                  _buildBrowser(context),
                  SizedBox(height: spacing.sm),
                  _buildSelectedPath(context),
                  SizedBox(height: spacing.xl),
                  _buildLibraryField(context),
                  SizedBox(height: spacing.lg),
                  _buildCollectionField(context),
                  SizedBox(height: spacing.lg),
                  _buildTransferModeField(context),
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
                label: '开始导入',
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

  Widget _buildFieldLabel(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.sm),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }

  Widget _buildBrowser(BuildContext context) {
    final listing = _listing;
    final spacing = context.appSpacing;
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            color: context.appColors.surfaceMuted,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
            child: Row(
              children: [
                AppIconButton(
                  size: AppIconButtonSize.mini,
                  tooltip: '上级目录',
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: listing?.parent == null
                      ? null
                      : () => _browse(listing!.parent),
                ),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: Text(
                    listing == null || listing.isRootsOverview
                        ? '媒体根目录'
                        : listing.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ),
                if (listing != null && !listing.isRootsOverview)
                  AppTextButton(
                    label: '选择此目录',
                    size: AppTextButtonSize.xSmall,
                    isSelected: _sourcePath == listing.path,
                    onPressed: () =>
                        setState(() => _sourcePath = listing.path),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appColors.divider),
          Expanded(child: _buildBrowserBody(context)),
        ],
      ),
    );
  }

  Widget _buildBrowserBody(BuildContext context) {
    if (_isBrowsing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_browseError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_browseError!),
            SizedBox(height: context.appSpacing.sm),
            AppTextButton(
              label: '重试',
              size: AppTextButtonSize.xSmall,
              onPressed: () => _browse(_listing?.path),
            ),
          ],
        ),
      );
    }
    final entries = _listing?.entries ?? const <FilesystemEntryDto>[];
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '该目录为空',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = _sourcePath == entry.path;
        return ListTile(
          key: Key('video-import-entry-${entry.path}'),
          dense: true,
          leading: Icon(
            entry.isDirectory
                ? Icons.folder_outlined
                : Icons.movie_outlined,
            color: context.appTextPalette.secondary,
          ),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          trailing: entry.isVideo
              ? Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: context.appComponentTokens.iconSizeSm,
                )
              : null,
          onTap: () {
            if (entry.isDirectory) {
              _browse(entry.path);
            } else if (entry.isVideo) {
              setState(() => _sourcePath = entry.path);
            }
          },
        );
      },
    );
  }

  Widget _buildSelectedPath(BuildContext context) {
    final selected = _sourcePath != null;
    return Row(
      children: [
        Text(
          '已选',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            _sourcePath ?? '尚未选择，请在上方选取目录或视频文件',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
              tone: selected ? AppTextTone.primary : AppTextTone.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryField(BuildContext context) {
    return AppSelectField<int>(
      key: const Key('video-import-library-select'),
      label: '导入到媒体库',
      placeholder:
          _libraries.isEmpty ? '暂无媒体库，请先在系统设置中添加' : '请选择媒体库',
      value: _libraryId,
      items: _libraries
          .map(
            (library) => DropdownMenuItem<int>(
              value: library.id,
              child: Text(library.name),
            ),
          )
          .toList(growable: false),
      onChanged: (value) => setState(() => _libraryId = value),
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
          placeholder:
              _collections.isEmpty ? '暂无合集，点右上「新建合集」' : '请选择合集',
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

  Widget _buildTransferModeField(BuildContext context) {
    return AppSelectField<TransferMode>(
      key: const Key('video-import-transfer-mode-select'),
      label: '导入方式',
      value: _transferMode,
      items: TransferMode.values
          .map(
            (mode) => DropdownMenuItem<TransferMode>(
              value: mode,
              child: Text(mode.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) =>
          setState(() => _transferMode = value ?? TransferMode.auto),
    );
  }
}
