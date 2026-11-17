import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/session/credential_store.dart';

part 'credential_store_provider.g.dart';

/// 全局 [CredentialStore] 的 Riverpod 入口。
///
/// 原生装配：body 直接构造，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
CredentialStore credentialStore(Ref ref) {
  return CredentialStore();
}
