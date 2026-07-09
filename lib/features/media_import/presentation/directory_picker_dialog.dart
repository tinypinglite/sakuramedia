import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 新建导入的确认结果。
class MediaImportRequest {
  const MediaImportRequest({
    required this.libraryId,
    required this.sourcePath,
    required this.transferMode,
  });

  final int libraryId;
  final String sourcePath;
  final TransferMode transferMode;
}

/// 弹出目录选择对话框；用户确认后返回 [MediaImportRequest]，取消返回 `null`。
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
  late final MediaImportApi _mediaImportApi;
  late final MediaLibrariesApi _librariesApi;

  FilesystemListResponseDto? _listing;
  bool _isBrowsing = true;
  String? _browseError;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  int? _selectedLibraryId;
  TransferMode _transferMode = TransferMode.auto;

  @override
  void initState() {
    super.initState();
    _mediaImportApi = context.read<MediaImportApi>();
    _librariesApi = context.read<MediaLibrariesApi>();
    unawaited(_browse(null));
    unawaited(_loadLibraries());
  }

  Future<void> _loadLibraries() async {
    try {
      final libraries = await _librariesApi.getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _selectedLibraryId ??=
            libraries.isNotEmpty ? libraries.first.id : null;
      });
    } catch (_) {
      // 媒体库加载失败时，下拉为空，开始导入按钮保持禁用。
    }
  }

  Future<void> _browse(String? path) async {
    setState(() {
      _isBrowsing = true;
      _browseError = null;
    });
    try {
      final listing = await _mediaImportApi.listEntries(path: path);
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
        _isBrowsing = false;
        _browseError = apiErrorMessage(error, fallback: '浏览目录失败，请重试。');
      });
    }
  }

  bool get _canSubmit {
    final listing = _listing;
    return listing != null &&
        !listing.isRootsOverview &&
        listing.path.isNotEmpty &&
        _selectedLibraryId != null;
  }

  Future<void> _submit() async {
    final listing = _listing;
    final libraryId = _selectedLibraryId;
    if (listing == null || libraryId == null || listing.path.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      MediaImportRequest(
        libraryId: libraryId,
        sourcePath: listing.path,
        transferMode: _transferMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      dialogKey: const Key('media-import-directory-picker-dialog'),
      width: context.appLayoutTokens.dialogWidthMd,
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
          _buildPathBar(context),
          SizedBox(height: spacing.sm),
          _buildBrowser(context),
          SizedBox(height: spacing.lg),
          _buildOptions(context),
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
                  onPressed: _canSubmit ? () => unawaited(_submit()) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar(BuildContext context) {
    final listing = _listing;
    final spacing = context.appSpacing;
    final canGoUp = listing?.parent != null && !_isBrowsing;
    final pathText = switch (listing) {
      null => '加载中…',
      final value when value.isRootsOverview => '选择一个白名单根目录',
      final value => value.path,
    };
    return Row(
      children: [
        AppIconButton(
          key: const Key('media-import-picker-up-button'),
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: '上一级',
          onPressed:
              canGoUp ? () => unawaited(_browse(listing!.parent)) : null,
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Text(
            pathText,
            key: const Key('media-import-picker-current-path'),
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
      ],
    );
  }

  Widget _buildBrowser(BuildContext context) {
    return Container(
      height: 280,
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
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
        ),
      );
    }
    if (_browseError != null) {
      return Padding(
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(message: _browseError!),
              SizedBox(height: context.appSpacing.md),
              AppButton(
                label: '重试',
                size: AppButtonSize.small,
                onPressed: () =>
                    unawaited(_browse(_listing?.path)),
              ),
            ],
          ),
        ),
      );
    }
    final listing = _listing;
    if (listing == null || listing.entries.isEmpty) {
      return const AppEmptyState(message: '该目录下没有可显示的子目录或视频文件');
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
      itemCount: listing.entries.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: context.appColors.divider),
      itemBuilder: (context, index) {
        final entry = listing.entries[index];
        return _EntryRow(
          entry: entry,
          onTap: entry.isDirectory
              ? () => unawaited(_browse(entry.path))
              : null,
        );
      },
    );
  }

  Widget _buildOptions(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSelectField<int>(
          key: const Key('media-import-picker-library-select'),
          label: '导入到媒体库',
          placeholder: _libraries.isEmpty ? '暂无媒体库，请先在系统设置中添加' : '请选择媒体库',
          value: _selectedLibraryId,
          items: _libraries
              .map(
                (library) => DropdownMenuItem<int>(
                  value: library.id,
                  child: Text(library.name),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _selectedLibraryId = value),
        ),
        SizedBox(height: spacing.md),
        AppSelectField<TransferMode>(
          key: const Key('media-import-picker-transfer-mode-select'),
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
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final FilesystemEntryDto entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final isDir = entry.isDirectory;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isDir
                  ? Icons.folder_rounded
                  : Icons.movie_outlined,
              size: context.appComponentTokens.iconSizeSm,
              color: isDir
                  ? context.appTextPalette.accent
                  : context.appTextPalette.muted,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: isDir ? AppTextTone.primary : AppTextTone.muted,
                ),
              ),
            ),
            if (!isDir) ...[
              SizedBox(width: spacing.sm),
              Text(
                formatFileSize(entry.size),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
            if (isDir) ...[
              SizedBox(width: spacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: context.appTextPalette.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
