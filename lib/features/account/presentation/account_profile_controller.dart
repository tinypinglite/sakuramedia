import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';

class AccountProfileController extends ChangeNotifier {
  AccountProfileController({required AccountApi accountApi})
    : _accountApi = accountApi;

  final AccountApi _accountApi;

  AccountDto? _account;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  AccountDto? get account => _account;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _account = await _accountApi.getAccount();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '账号资料加载失败，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveUsername(String username) async {
    if (_isSaving) {
      return false;
    }

    final normalized = username.trim();
    if (normalized.isEmpty) {
      _errorMessage = '请输入用户名';
      notifyListeners();
      return false;
    }

    if (normalized == (_account?.username.trim() ?? '')) {
      _errorMessage = '用户名未变化';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _account = await _accountApi.updateUsername(normalized);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = accountProfileErrorMessage(error, fallback: '修改用户名失败');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

String accountProfileErrorMessage(Object error, {required String fallback}) {
  if (error is ApiException && error.error?.code == 'username_conflict') {
    return '用户名已存在，请换一个名称';
  }
  return apiErrorMessage(error, fallback: fallback);
}
