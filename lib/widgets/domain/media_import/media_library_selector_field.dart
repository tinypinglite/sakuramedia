import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 媒体导入弹窗顶部的媒体库选择器：读取共享的媒体库 provider，渲染
/// loading/error/empty 状态和下拉选项。
///
/// 边界：
/// - 列表与加载/错误状态来自 [mediaLibrariesProvider]，caller 只持有
///   [selectedLibraryId]。
/// - 首次成功加载后，若 caller 未指定选中值，自动通过 [onLibraryChanged] 上抛
///   列表首项；若 caller 已指定但该 id 在新列表里找不到，会回退到首项。
/// - dropdown 条目标签使用 `名称 · provider_key`，不暴露任何 provider 专属分支。
class MediaLibrarySelectorField extends ConsumerStatefulWidget {
  const MediaLibrarySelectorField({
    super.key,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
  });

  final int? selectedLibraryId;

  /// 选中变化时的回调；`null` 表示媒体库列表为空 / 加载失败。
  final ValueChanged<MediaLibraryDto?> onLibraryChanged;

  @override
  ConsumerState<MediaLibrarySelectorField> createState() =>
      _MediaLibrarySelectorFieldState();
}

class _MediaLibrarySelectorFieldState
    extends ConsumerState<MediaLibrarySelectorField> {
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(mediaLibrariesProvider);
    if (cached.hasValue) {
      _libraries = cached.requireValue;
      _isLoading = false;
      _syncSelection(_libraries);
    } else if (cached.hasError && !cached.isLoading) {
      _isLoading = false;
      _loadError = cached.error;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load({bool forceReload = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      if (forceReload) {
        await ref.read(mediaLibrariesProvider.notifier).reload();
        if (!mounted) {
          return;
        }
      }
      final libraries = await ref.read(mediaLibrariesProvider.future);
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _isLoading = false;
      });
      _syncSelection(libraries);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  /// 让 caller 与列表状态对齐：若当前选中不再存在，回落到首项。
  void _syncSelection(List<MediaLibraryDto> libraries) {
    final currentId = widget.selectedLibraryId;
    final matches = libraries.any((library) => library.id == currentId);
    if (matches) {
      return;
    }
    scheduleMicrotask(() {
      if (mounted) {
        widget.onLibraryChanged(libraries.isEmpty ? null : libraries.first);
      }
    });
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
    final l10n = AppLocalizations.of(context);
    final errorMessage = _loadError == null
        ? null
        : apiErrorMessage(
            _loadError!,
            fallback: l10n.widgetMediaImportLibraryLoadFailed,
            l10n: l10n,
          );
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (errorMessage != null) {
      return Column(
        children: [
          AppEmptyState(message: errorMessage),
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-library-retry-button'),
            label: l10n.widgetMediaImportReloadLibraries,
            size: AppButtonSize.small,
            onPressed: () => unawaited(_load(forceReload: true)),
          ),
        ],
      );
    }
    if (_libraries.isEmpty) {
      return AppEmptyState(message: l10n.widgetMediaImportNoLibraries);
    }
    return AppSelectField<int>(
      key: const Key('media-import-library-select'),
      label: l10n.widgetMediaImportLibraryLabel,
      value: widget.selectedLibraryId,
      items: _libraries
          .map(
            (library) => DropdownMenuItem<int>(
              value: library.id,
              child: Text('${library.name} · ${library.providerKey}'),
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
