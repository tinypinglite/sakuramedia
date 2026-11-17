import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/media_import/data/import_metadata_search_dto.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';

part 'import_metadata_match_provider.g.dart';

@immutable
class ImportMetadataMatchState {
  const ImportMetadataMatchState({
    this.isLoading = false,
    this.hasSearched = false,
    this.response,
    this.errorMessage,
  });

  final bool isLoading;
  final bool hasSearched;
  final ImportMetadataSearchResponseDto? response;
  final String? errorMessage;
}

/// 单个失败文件的人工元数据搜索状态；结果按 (任务运行, 失败项) 隔离。
@riverpod
class ImportMetadataMatch extends _$ImportMetadataMatch {
  bool _isDisposed = false;

  @override
  ImportMetadataMatchState build(int taskRunId, String itemId) {
    ref.onDispose(() => _isDisposed = true);
    return const ImportMetadataMatchState();
  }

  Future<void> search(String movieNumber) async {
    final number = movieNumber.trim();
    if (_isDisposed || state.isLoading || number.isEmpty) return;
    state = const ImportMetadataMatchState(isLoading: true, hasSearched: true);
    ImportMetadataSearchResponseDto? response;
    String? errorMessage;
    try {
      response = await ref
          .read(mediaImportApiProvider)
          .searchMetadataCandidates(
            taskRunId: taskRunId,
            itemId: itemId,
            movieNumber: number,
          );
    } catch (_) {
      errorMessage = ref
          .read(appLocalizationsProvider)
          .mediaImportMetadataSearchFailed;
    }
    if (_isDisposed) return;
    state = ImportMetadataMatchState(
      hasSearched: true,
      response: response,
      errorMessage: errorMessage,
    );
  }
}
