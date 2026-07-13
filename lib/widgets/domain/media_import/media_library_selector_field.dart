import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 媒体导入弹窗顶部的媒体库选择器：自管媒体库加载、错误/空态/重试、下拉渲染。
///
/// 边界：
/// - **自管** 媒体库列表 + loading/error state，caller 只持有 [selectedLibraryId]。
/// - 首次成功加载后，若 caller 未指定选中值，自动通过 [onLibraryChanged] 上抛
///   列表首项；若 caller 已指定但该 id 在新列表里找不到，会回退到首项。
/// - dropdown 条目标签固定为 `名称 · 本地存储 / 115 网盘`，两个导入弹窗共用。
class MediaLibrarySelectorField extends StatefulWidget {
  const MediaLibrarySelectorField({
    super.key,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
  });

  final int? selectedLibraryId;

  /// 选中变化时的回调；`null` 表示媒体库列表为空 / 加载失败。
  final ValueChanged<MediaLibraryDto?> onLibraryChanged;

  @override
  State<MediaLibrarySelectorField> createState() =>
      _MediaLibrarySelectorFieldState();
}

class _MediaLibrarySelectorFieldState extends State<MediaLibrarySelectorField> {
  late final MediaLibrariesApi _librariesApi;

  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _librariesApi = context.read<MediaLibrariesApi>();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final libraries = await _librariesApi.getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _isLoading = false;
      });
      // 让 caller 与列表状态对齐：若当前选中不再存在，回落到首项。
      final currentId = widget.selectedLibraryId;
      final matches = libraries.any((library) => library.id == currentId);
      if (!matches) {
        scheduleMicrotask(() {
          if (!mounted) {
            return;
          }
          widget.onLibraryChanged(libraries.isEmpty ? null : libraries.first);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = apiErrorMessage(error, fallback: '媒体库加载失败，请重试。');
      });
    }
  }

  MediaLibraryDto? _libraryById(int? id) {
    if (id == null) {
      return null;
    }
    for (final library in _libraries) {
      if (library.id == id) {
        return library;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Column(
        children: [
          AppEmptyState(message: _error!),
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-library-retry-button'),
            label: '重新加载媒体库',
            size: AppButtonSize.small,
            onPressed: () => unawaited(_load()),
          ),
        ],
      );
    }
    if (_libraries.isEmpty) {
      return const AppEmptyState(message: '暂无媒体库，请先在系统设置中添加媒体库。');
    }
    return AppSelectField<int>(
      key: const Key('media-import-library-select'),
      label: '导入到媒体库',
      value: widget.selectedLibraryId,
      items: _libraries
          .map(
            (library) => DropdownMenuItem<int>(
              value: library.id,
              child: Text(
                '${library.name} · ${library.isCloud115 ? '115 网盘' : '本地存储'}',
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null || value == widget.selectedLibraryId) {
          return;
        }
        widget.onLibraryChanged(_libraryById(value));
      },
    );
  }
}
