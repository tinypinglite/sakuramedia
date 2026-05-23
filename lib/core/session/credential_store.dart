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
    } catch (_) {
      // Silently fail when storage is unavailable (e.g., tests, web).
    }
  }

  Future<String?> readUsername() {
    return _safeRead(_usernameKey);
  }

  Future<String?> readPassword() {
    return _safeRead(_passwordKey);
  }

  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: _usernameKey),
      _storage.delete(key: _passwordKey),
    ]);
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
