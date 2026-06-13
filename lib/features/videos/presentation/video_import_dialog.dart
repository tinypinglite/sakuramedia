import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/video_import_result_dto.dart';
import 'package:sakuramedia/features/videos/data/video_imports_api.dart';
import 'package:sakuramedia/features/videos/presentation/person_selection_controller.dart';
import 'package:sakuramedia/features/videos/presentation/person_selector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';

/// 打开视频导入对话框：浏览后端目录选取源路径，按需关联库/标签/人物/合集并就地索引。
/// 返回导入结果 [VideoImportResultDto]，取消返回 `null`。
Future<VideoImportResultDto?> showVideoImportDialog(BuildContext context) {
  return showDialog<VideoImportResultDto>(
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
  late final TagSelectionController _tagSelection;
  late final PersonSelectionController _personSelection;

  FilesystemListResponseDto? _listing;
  bool _isBrowsing = true;
  String? _browseError;
  String? _sourcePath;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  int? _libraryId;
  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  int? _collectionId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _filesystemApi = context.read<MediaImportApi>();
    _tagSelection =
        TagSelectionController(tagsApi: context.read<TagsApi>(), popularLimit: 20);
    _personSelection =
        PersonSelectionController(personsApi: context.read<PersonsApi>());
    unawaited(_tagSelection.load());
    unawaited(_personSelection.load());
    _browse(null);
    _loadLibraries();
    _loadCollections();
  }

  @override
  void dispose() {
    _tagSelection.dispose();
    _personSelection.dispose();
    super.dispose();
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
      final libraries = await context.read<MediaLibrariesApi>().getLibraries();
      if (mounted) {
        setState(() => _libraries = libraries);
      }
    } catch (_) {
      // 库列表为可选项，加载失败不阻塞导入。
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
      // 合集为可选项，加载失败不阻塞导入。
    }
  }

  Future<void> _submit() async {
    final sourcePath = _sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      showToast('请先选择要导入的目录或视频文件');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await context.read<VideoImportsApi>().createVideoImport(
            sourcePath: sourcePath,
            libraryId: _libraryId,
            tagIds: _tagSelection.selectedTagIds,
            personIds: _personSelection.selectedPersonIds,
            collectionId: _collectionId,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '导入失败'));
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入视频',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrowser(context),
                  SizedBox(height: spacing.md),
                  _buildSelectedPath(context),
                  SizedBox(height: spacing.md),
                  _buildLibrarySelect(context),
                  SizedBox(height: spacing.sm),
                  _buildCollectionSelect(context),
                  SizedBox(height: spacing.md),
                  AnimatedBuilder(
                    animation: _tagSelection,
                    builder: (context, _) => TagSelectorPanel(
                      selection: _tagSelection,
                      onToggleTag: _tagSelection.toggle,
                      onRemoveTag: _tagSelection.remove,
                      onClear: _tagSelection.clear,
                      onQueryChanged: _tagSelection.setQuery,
                      onToggleExpanded: _tagSelection.toggleExpanded,
                      onMatchModeChanged: (_) {},
                      showMatchModeToggle: false,
                      onRetry: () => unawaited(_tagSelection.retry()),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  AnimatedBuilder(
                    animation: _personSelection,
                    builder: (context, _) => PersonSelectorPanel(
                      selection: _personSelection,
                      onTogglePerson: _personSelection.toggle,
                      onRemovePerson: _personSelection.remove,
                      onClear: _personSelection.clear,
                      onQueryChanged: _personSelection.setQuery,
                      onRetry: () => unawaited(_personSelection.retry()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('video-import-submit-button'),
                  label: '开始导入',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrowser(BuildContext context) {
    final listing = _listing;
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
              vertical: context.appSpacing.xs,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: context.appComponentTokens.iconSizeSm,
                  tooltip: '上级目录',
                  onPressed: listing?.parent == null
                      ? null
                      : () => _browse(listing!.parent),
                ),
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
                      weight: AppTextWeight.regular,
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
          const Divider(height: 1),
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
    return Row(
      children: [
        Text(
          '导入源：',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        Expanded(
          child: Text(
            _sourcePath ?? '尚未选择',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: _sourcePath == null
                  ? AppTextTone.muted
                  : AppTextTone.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLibrarySelect(BuildContext context) {
    return AppSelectField<int?>(
      label: '媒体库（可选）',
      value: _libraryId,
      placeholder: '不指定',
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('不指定')),
        for (final library in _libraries)
          DropdownMenuItem<int?>(
            value: library.id,
            child: Text(library.name),
          ),
      ],
      onChanged: (value) => setState(() => _libraryId = value),
    );
  }

  Widget _buildCollectionSelect(BuildContext context) {
    return AppSelectField<int?>(
      label: '加入合集（可选）',
      value: _collectionId,
      placeholder: '不指定',
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('不指定')),
        for (final collection in _collections)
          DropdownMenuItem<int?>(
            value: collection.id,
            child: Text(collection.name),
          ),
      ],
      onChanged: (value) => setState(() => _collectionId = value),
    );
  }
}
