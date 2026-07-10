import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';

/// 双端索引器设置页共用的 Jackett 连通性测试状态。
///
/// 表单配置变化时调用 [invalidate]：会清除旧结果，并让在途请求的回包失效，
/// 避免把旧配置的测试结果展示为当前配置的状态。
class IndexerConnectionTestController extends ChangeNotifier {
  IndexerConnectionTestController({required this.runTest});

  final Future<IndexerConnectionTestResultDto> Function() runTest;

  bool _isTesting = false;
  int _configurationVersion = 0;
  IndexerConnectionTestResultDto? _result;
  String? _requestError;

  bool get isTesting => _isTesting;
  IndexerConnectionTestResultDto? get result => _result;
  String? get requestError => _requestError;

  void invalidate({bool notify = true}) {
    _configurationVersion += 1;
    _result = null;
    _requestError = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<IndexerConnectionTestResultDto?> testConnection() async {
    if (_isTesting) {
      return null;
    }
    final requestVersion = _configurationVersion;
    _isTesting = true;
    _result = null;
    _requestError = null;
    notifyListeners();

    try {
      final result = await runTest();
      if (requestVersion != _configurationVersion) {
        return null;
      }
      _result = result;
      return result;
    } catch (error) {
      if (requestVersion == _configurationVersion) {
        _requestError = apiErrorMessage(error, fallback: 'Jackett 连通性测试请求失败');
      }
      return null;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }
}
