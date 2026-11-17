import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';

/// 账号资料 State（含加载/保存中标志与错误消息）。
///
/// AsyncValue 表达不了「保留旧 [account] + 附带 [errorMessage] + 保存中」四态
/// 复合，故用同步 [Notifier] + 显式字段。
@immutable
class AccountProfileState {
  const AccountProfileState({
    this.account,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final AccountDto? account;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AccountProfileState copyWith({
    Object? account = _kSentinel,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _kSentinel,
  }) {
    return AccountProfileState(
      account: identical(account, _kSentinel)
          ? this.account
          : account as AccountDto?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: identical(errorMessage, _kSentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _kSentinel = Object();
