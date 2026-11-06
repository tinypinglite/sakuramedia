import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';

part 'indexer_connection_test_provider.g.dart';

@immutable
class IndexerConnectionTestState {
  const IndexerConnectionTestState({
    this.isTesting = false,
    this.result,
    this.requestError,
    this.configurationVersion = 0,
  });

  final bool isTesting;
  final IndexerConnectionTestResultDto? result;
  final String? requestError;
  final int configurationVersion;

  IndexerConnectionTestState copyWith({
    bool? isTesting,
    IndexerConnectionTestResultDto? result,
    bool clearResult = false,
    String? requestError,
    bool clearRequestError = false,
  }) {
    return IndexerConnectionTestState(
      isTesting: isTesting ?? this.isTesting,
      result: clearResult ? null : result ?? this.result,
      requestError: clearRequestError
          ? null
          : requestError ?? this.requestError,
    );
  }
}

/// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。
@riverpod
class IndexerConnectionTest extends _$IndexerConnectionTest {
  var _disposed = false;

  @override
  IndexerConnectionTestState build(Object scope) {
    ref.onDispose(() => _disposed = true);
    return const IndexerConnectionTestState();
  }

  void invalidate() {
    state = IndexerConnectionTestState(
      configurationVersion: state.configurationVersion + 1,
    );
  }

  Future<IndexerConnectionTestResultDto?> testConnection(
    Future<IndexerConnectionTestResultDto> Function() runTest,
  ) async {
    if (state.isTesting) return null;
    final requestVersion = state.configurationVersion;
    state = state.copyWith(
      isTesting: true,
      clearResult: true,
      clearRequestError: true,
    );
    try {
      final result = await runTest();
      if (_disposed || requestVersion != state.configurationVersion) {
        return null;
      }
      state = state.copyWith(result: result);
      return result;
    } catch (error) {
      if (!_disposed && requestVersion == state.configurationVersion) {
        state = state.copyWith(
          requestError: ref.apiErrorMessage(
            error,
            fallback: ref
                .read(appLocalizationsProvider)
                .errorTorznabConnectionTestFailed,
          ),
        );
      }
      return null;
    } finally {
      if (!_disposed) state = state.copyWith(isTesting: false);
    }
  }
}
