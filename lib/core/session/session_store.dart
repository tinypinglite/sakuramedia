import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_snapshot.dart';

abstract class SessionStorageBackend {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesSessionStorageBackend implements SessionStorageBackend {
  SharedPreferencesSessionStorageBackend(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) {
    return _preferences.getString(key);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _preferences.setString(key, value);
  }
}

class InMemorySessionStorageBackend implements SessionStorageBackend {
  final Map<String, String> _storage = <String, String>{};

  @override
  String? getString(String key) {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }
}

class SessionStore extends ChangeNotifier {
  SessionStore._(this._backend) {
    _snapshot = _readSnapshot();
  }

  static const String _baseUrlKey = 'session.base_url';
  static const String _accessTokenKey = 'session.access_token';
  static const String _refreshTokenKey = 'session.refresh_token';
  static const String _expiresAtKey = 'session.expires_at';

  final SessionStorageBackend _backend;
  late SessionSnapshot _snapshot;

  static Future<SessionStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SessionStore._(SharedPreferencesSessionStorageBackend(preferences));
  }

  factory SessionStore.inMemory() {
    return SessionStore._(InMemorySessionStorageBackend());
  }

  SessionSnapshot get snapshot => _snapshot;
  String get baseUrl => _snapshot.baseUrl;
  String get accessToken => _snapshot.accessToken;
  String get refreshToken => _snapshot.refreshToken;
  DateTime? get expiresAt => _snapshot.expiresAt;
  bool get hasSession => _snapshot.hasSession;

  Future<SessionSnapshot> readSession() async {
    _snapshot = _readSnapshot();
    notifyListeners();
    return _snapshot;
  }

  Future<void> saveBaseUrl(String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      await _backend.remove(_baseUrlKey);
    } else {
      await _backend.setString(_baseUrlKey, normalized);
    }
    _snapshot = _snapshot.copyWith(baseUrl: normalized);
    notifyListeners();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _backend.setString(_accessTokenKey, accessToken);
    await _backend.setString(_refreshTokenKey, refreshToken);
    await _backend.setString(
      _expiresAtKey,
      expiresAt.toUtc().toIso8601String(),
    );

    _snapshot = _snapshot.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _backend.remove(_accessTokenKey);
    await _backend.remove(_refreshTokenKey);
    await _backend.remove(_expiresAtKey);

    _snapshot = _snapshot.copyWith(
      accessToken: '',
      refreshToken: '',
      clearExpiresAt: true,
    );
    notifyListeners();
  }

  SessionSnapshot _readSnapshot() {
    final expiresAtRaw = _backend.getString(_expiresAtKey);
    return SessionSnapshot(
      baseUrl: _backend.getString(_baseUrlKey) ?? '',
      accessToken: _backend.getString(_accessTokenKey) ?? '',
      refreshToken: _backend.getString(_refreshTokenKey) ?? '',
      expiresAt: expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw),
    );
  }
}
