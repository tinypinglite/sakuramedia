import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';

extension AuthActions on BuildContext {
  /// 统一登出出口：清空会话并清除已保存的登录凭据。
  ///
  /// 在任何 await 之前先取出依赖，避免 await 后 context 失效再读取 Provider；
  /// 先清空会话以触发 GoRouter 立即重定向到登录页，凭据清除随后进行，
  /// 不让其 I/O 阻塞登出的可见跳转。
  Future<void> logOut() async {
    final container = ProviderScope.containerOf(this, listen: false);
    final credentialStore = container.read(credentialStoreProvider);
    final sessionStore = container.read(sessionStoreProvider);
    await sessionStore.clearSession();
    await credentialStore.clearCredentials();
  }
}
