import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 把请求异常转成用户可读文案。
///
/// 服务端返回的 [ApiException.error] 已经按请求语言本地化；这里只兜底
/// 传输失败和非 [ApiException]。传输失败文案走 ARB，因此 [l10n] 必传：
/// 漏传会编译报错，不会再静默退回中文。
String apiErrorMessage(
  Object error, {
  required String fallback,
  required AppLocalizations l10n,
}) {
  if (error is ApiException) {
    if (error.isTransportFailure) {
      return _transportFailureMessage(error, l10n);
    }
    return error.error?.message ?? error.message;
  }
  return fallback;
}

String _transportFailureMessage(ApiException error, AppLocalizations l10n) {
  final baseUrl = error.baseUrl?.trim();
  return switch (error.transportFailureKind) {
    ApiTransportFailureKind.timeout
        when baseUrl != null && baseUrl.isNotEmpty =>
      l10n.errorTimeoutWithHost(baseUrl),
    ApiTransportFailureKind.timeout => l10n.errorTimeout,
    _ when baseUrl != null && baseUrl.isNotEmpty =>
      l10n.errorNetworkFailureWithHost(baseUrl),
    _ => l10n.errorNetworkFailure,
  };
}
