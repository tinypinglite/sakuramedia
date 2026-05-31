import 'package:sakuramedia/core/session/credential_store.dart';

/// 测试用内存版 [CredentialStore]，避免依赖平台 secure storage。
class InMemoryCredentialStore implements CredentialStore {
  String? username;
  String? password;

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    this.username = username;
    this.password = password;
  }

  @override
  Future<String?> readUsername() async => username;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> clearCredentials() async {
    username = null;
    password = null;
  }
}
