import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _usernameKey = 'credential.username';
  static const _passwordKey = 'credential.password';

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _usernameKey, value: username),
        _storage.write(key: _passwordKey, value: password),
      ]);
    } catch (error, stackTrace) {
      // 存储不可用（如测试、Web）时不阻断登录，但记录下来便于排查，
      // 而不是完全静默。
      debugPrint('CredentialStore.saveCredentials failed: $error\n$stackTrace');
    }
  }

  Future<String?> readUsername() {
    return _safeRead(_usernameKey);
  }

  Future<String?> readPassword() {
    return _safeRead(_passwordKey);
  }

  Future<void> clearCredentials() async {
    try {
      await Future.wait([
        _storage.delete(key: _usernameKey),
        _storage.delete(key: _passwordKey),
      ]);
    } catch (error, stackTrace) {
      // 存储删除失败不应阻断登出流程，记录后继续。
      debugPrint(
        'CredentialStore.clearCredentials failed: $error\n$stackTrace',
      );
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
