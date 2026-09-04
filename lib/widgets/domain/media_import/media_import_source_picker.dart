import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_source_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

/// Provider-neutral source browser used by the media import dialogs.
///
/// The provider owns the meaning of every source reference. The host only
/// forwards the selected opaque object to `POST /imports`.
class MediaImportSourcePicker extends ConsumerStatefulWidget {
  const MediaImportSourcePicker({
    super.key,
    required this.selectedLibrary,
    required this.sourceDisposition,
    required this.onSourceChanged,
    required this.onSourceDispositionChanged,
    this.allowFileSource = false,
  });

  final MediaLibraryDto? selectedLibrary;
  final SourceDisposition sourceDisposition;
  final ValueChanged<MediaImportSource?> onSourceChanged;
  final ValueChanged<SourceDisposition> onSourceDispositionChanged;

  /// JAV imports select directories by default. Video imports may also select
  /// a provider file entry when this flag is enabled.
  final bool allowFileSource;

  @override
  ConsumerState<MediaImportSourcePicker> createState() =>
      _MediaImportSourcePickerState();
}

class _MediaImportSourcePickerState
    extends ConsumerState<MediaImportSourcePicker> {
  static const int _pageSize = 50;

  late final MediaImportApi _mediaImportApi;
  ImportBrowseResponseDto? _page;
  List<ImportBrowseEntryDto> _entries = const <ImportBrowseEntryDto>[];
  List<_BrowseSegment> _path = const <_BrowseSegment>[];
  Map<String, dynamic>? _parentRef;
  ImportBrowseEntryDto? _selectedEntry;
  bool _isCurrentDirectorySelected = false;

  bool _isBrowsing = false;
  bool _isLoadingMore = false;
  String? _browseError;
  String? _loadMoreError;
  int _browseGeneration = 0;

  @override
  void initState() {
    super.initState();
    _mediaImportApi = ref.read(mediaImportApiProvider);
    final library = widget.selectedLibrary;
    if (library != null) {
      unawaited(_resetAndBrowse(library));
    }
  }

  @override
  void didUpdateWidget(covariant MediaImportSourcePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLibrary?.id != widget.selectedLibrary?.id &&
        widget.selectedLibrary != null) {
      unawaited(_resetAndBrowse(widget.selectedLibrary!));
    }
  }

  @override
  void dispose() {
    _browseGeneration += 1;
    super.dispose();
  }

  Future<void> _resetAndBrowse(MediaLibraryDto library) async {
    final generation = ++_browseGeneration;
    scheduleMicrotask(() {
      if (mounted) {
        widget.onSourceChanged(null);
      }
    });
    setState(() {
      _page = null;
      _entries = const <ImportBrowseEntryDto>[];
      _path = const <_BrowseSegment>[];
      _parentRef = null;
      _selectedEntry = null;
      _isCurrentDirectorySelected = false;
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = false;
      _isBrowsing = true;
    });
    await _fetchPage(generation: generation, libraryId: library.id);
  }

  Future<void> _browseFolder(ImportBrowseEntryDto entry) async {
    final library = widget.selectedLibrary;
    if (library == null || !entry.isDirectory) {
      return;
    }
    final nextPath = <_BrowseSegment>[
      ..._path,
      _BrowseSegment(name: entry.name, parentRef: entry.sourceRef),
    ];
    final generation = ++_browseGeneration;
    widget.onSourceChanged(null);
    setState(() {
      _page = null;
      _entries = const <ImportBrowseEntryDto>[];
      _path = nextPath;
      _parentRef = entry.sourceRef;
      _selectedEntry = null;
      _isCurrentDirectorySelected = false;
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = false;
      _isBrowsing = true;
    });
    await _fetchPage(
      generation: generation,
      libraryId: library.id,
      parentRef: entry.sourceRef,
    );
  }

  Future<void> _browseParent() async {
    final library = widget.selectedLibrary;
    if (library == null || _path.isEmpty) {
      return;
    }
    final nextPath = _path.sublist(0, _path.length - 1);
    final parentRef = nextPath.isEmpty ? null : nextPath.last.parentRef;
    final generation = ++_browseGeneration;
    widget.onSourceChanged(null);
    setState(() {
      _page = null;
      _entries = const <ImportBrowseEntryDto>[];
      _path = nextPath;
      _parentRef = parentRef;
      _selectedEntry = null;
      _isCurrentDirectorySelected = false;
      _browseError = null;
      _loadMoreError = null;
      _isLoadingMore = true;
      _isBrowsing = true;
    });
    await _fetchPage(
      generation: generation,
      libraryId: library.id,
      parentRef: parentRef,
    );
  }

  Future<void> _fetchPage({
    required int generation,
    required int libraryId,
    Map<String, dynamic>? parentRef,
    String? cursor,
  }) async {
    try {
      final page = await _mediaImportApi.browseSources(
        libraryId: libraryId,
        parentRef: parentRef,
        cursor: cursor,
        limit: _pageSize,
      );
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _page = page;
        _entries = cursor == null
            ? page.entries
            : <ImportBrowseEntryDto>[..._entries, ...page.entries];
        _isBrowsing = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _isBrowsing = false;
        _isLoadingMore = false;
        _browseError = _browseErrorMessage(error);
      });
    }
  }

  Future<void> _loadMore() async {
    final library = widget.selectedLibrary;
    final cursor = _page?.nextCursor;
    if (library == null || cursor == null || _isLoadingMore) {
      return;
    }
    final generation = _browseGeneration;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await _mediaImportApi.browseSources(
        libraryId: library.id,
        parentRef: _parentRef,
        cursor: cursor,
        limit: _pageSize,
      );
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _page = page;
        _entries = <ImportBrowseEntryDto>[..._entries, ...page.entries];
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _browseGeneration) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = _browseErrorMessage(error);
      });
    }
  }

  void _selectFile(ImportBrowseEntryDto entry) {
    if (entry.isDirectory || !widget.allowFileSource) {
      return;
    }
    setState(() {
      _selectedEntry = entry;
      _isCurrentDirectorySelected = false;
    });
    widget.onSourceChanged(MediaImportSource(sourceRef: entry.sourceRef));
  }

  void _selectCurrentDirectory() {
    final parentRef = _parentRef;
    if (parentRef == null) {
      return;
    }
    setState(() {
      _selectedEntry = null;
      _isCurrentDirectorySelected = true;
    });
    widget.onSourceChanged(MediaImportSource(sourceRef: parentRef));
  }

  String _browseErrorMessage(Object error) =>
      apiErrorMessage(error, fallback: '浏览来源失败，请重试。');

  void _retryBrowse() {
    final library = widget.selectedLibrary;
    if (library == null) {
      return;
    }
    final generation = ++_browseGeneration;
    setState(() {
      _browseError = null;
      _isBrowsing = true;
    });
    unawaited(
      _fetchPage(
        generation: generation,
        libraryId: library.id,
        parentRef: _parentRef,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.selectedLibrary;
    if (library == null) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPathBar(context),
        SizedBox(height: context.appSpacing.sm),
        _buildBrowser(context),
        SizedBox(height: context.appSpacing.lg),
        _buildSourceDispositionSelector(context),
        if (widget.sourceDisposition ==
            SourceDisposition.deleteAfterCommit) ...[
          SizedBox(height: context.appSpacing.md),
          const AppNoticeCard(
            key: Key('media-import-source-disposition-warning'),
            leadingIcon: Icons.warning_amber_rounded,
            title: '导入成功后将删除源文件',
            description: '仅在媒体已成功入库后由存储提供方执行删除。',
          ),
        ],
      ],
    );
  }

  Widget _buildPathBar(BuildContext context) {
    final canGoUp = !_isBrowsing && _path.isNotEmpty;
    final pathText = _path.isEmpty
        ? '选择来源'
        : _path.map((segment) => segment.name).join(' / ');
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final selectButton = AppButton(
      key: const Key('media-import-picker-select-current-directory-button'),
      label: _isCurrentDirectorySelected ? '已选择当前目录' : '选择当前目录',
      size: isMobile ? AppButtonSize.medium : AppButtonSize.small,
      isSelected: _isCurrentDirectorySelected,
      onPressed: !_isBrowsing && _parentRef != null
          ? _selectCurrentDirectory
          : null,
    );
    final path = Row(
      children: [
        AppIconButton(
          key: const Key('media-import-picker-up-button'),
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: '上一级',
          onPressed: canGoUp ? () => unawaited(_browseParent()) : null,
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            pathText,
            key: const Key('media-import-picker-current-path'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
        if (!isMobile) ...[
          SizedBox(width: context.appSpacing.sm),
          selectButton,
        ],
      ],
    );
    if (!isMobile) return path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        path,
        SizedBox(height: context.appSpacing.sm),
        selectButton,
      ],
    );
  }

  Widget _buildBrowser(BuildContext context) {
    return Container(
      height: context.appLayoutTokens.directoryBrowserHeight,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildBrowserBody(context),
    );
  }

  Widget _buildBrowserBody(BuildContext context) {
    if (_isBrowsing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_browseError != null) {
      return SingleChildScrollView(
        child: AppEmptyState(
          message: _browseError!,
          retryKey: const Key('media-import-picker-browse-retry-button'),
          onRetry: _retryBrowse,
        ),
      );
    }
    if (_entries.isEmpty) {
      return const AppEmptyState(message: '该来源下没有可导入的文件或目录');
    }
    final showFooter =
        _page?.nextCursor != null || _loadMoreError != null || _isLoadingMore;
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
      itemCount: _entries.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appColors.divider),
      itemBuilder: (context, index) {
        if (index == _entries.length) {
          return _buildLoadMoreFooter(context);
        }
        final entry = _entries[index];
        return _ImportEntryRow(
          key: Key('media-import-entry-$index'),
          entry: entry,
          selected: identical(entry, _selectedEntry),
          canSelect: !entry.isDirectory && widget.allowFileSource,
          onTap: entry.isDirectory
              ? () => unawaited(_browseFolder(entry))
              : () => _selectFile(entry),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    if (_isLoadingMore) {
      return Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: EdgeInsets.all(context.appSpacing.sm),
      child: Column(
        children: [
          if (_loadMoreError != null)
            Text(
              _loadMoreError!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          AppButton(
            key: const Key('media-import-picker-load-more-button'),
            label: _loadMoreError == null ? '加载更多' : '重试加载',
            size: AppButtonSize.small,
            onPressed: () => unawaited(_loadMore()),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceDispositionSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelectField<SourceDisposition>(
          key: const Key('media-import-picker-source-disposition-select'),
          label: '源文件处理',
          value: widget.sourceDisposition,
          items: SourceDisposition.values
              .map(
                (disposition) => DropdownMenuItem<SourceDisposition>(
                  value: disposition,
                  child: Text(disposition.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) {
              widget.onSourceDispositionChanged(value);
            }
          },
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          '源文件处理方式由存储提供方执行，导入任务会在任务中心显示结果。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }
}

class _BrowseSegment {
  const _BrowseSegment({required this.name, required this.parentRef});

  final String name;
  final Map<String, dynamic> parentRef;
}

class _ImportEntryRow extends StatelessWidget {
  const _ImportEntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.canSelect,
    required this.onTap,
  });

  final ImportBrowseEntryDto entry;
  final bool selected;
  final bool canSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final muted = !entry.isDirectory && !canSelect;
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    return InkWell(
      onTap: entry.isDirectory || canSelect ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: isMobile ? spacing.md : spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              entry.isDirectory ? Icons.folder_rounded : Icons.movie_outlined,
              size: context.appComponentTokens.iconSizeSm,
              color: selected
                  ? context.appTextPalette.accent
                  : muted
                  ? context.appTextPalette.muted
                  : entry.isDirectory
                  ? context.appTextPalette.accent
                  : context.appTextPalette.muted,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                entry.name,
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: isMobile ? AppTextSize.s14 : AppTextSize.s12,
                  tone: muted ? AppTextTone.muted : AppTextTone.primary,
                ),
              ),
            ),
            if (selected)
              Padding(
                padding: EdgeInsets.only(left: spacing.sm),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                  color: context.appTextPalette.accent,
                ),
              ),
            if (entry.isDirectory)
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: context.appTextPalette.muted,
              )
            else if (!entry.isDirectory && entry.sizeBytes != null) ...[
              SizedBox(width: spacing.sm),
              Text(
                formatFileSize(entry.sizeBytes!),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
