import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save/read/clear session fields', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await SessionStore.create();

    await store.saveBaseUrl('http://127.0.0.1:8000');
    await store.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );

    final snapshot = await store.readSession();
    expect(snapshot.baseUrl, 'http://127.0.0.1:8000');
    expect(snapshot.accessToken, 'access-token');
    expect(snapshot.refreshToken, 'refresh-token');
    expect(snapshot.expiresAt, DateTime.parse('2026-03-08T10:00:00Z'));

    await store.clearSession();
    final cleared = await store.readSession();
    expect(cleared.baseUrl, 'http://127.0.0.1:8000');
    expect(cleared.accessToken, isEmpty);
    expect(cleared.refreshToken, isEmpty);
    expect(cleared.expiresAt, isNull);
  });

  test('new store instance restores persisted values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final firstStore = await SessionStore.create();
    await firstStore.saveBaseUrl('https://example.com');
    await firstStore.saveTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.parse('2026-03-09T10:00:00Z'),
    );

    final restoredStore = await SessionStore.create();
    final restored = await restoredStore.readSession();

    expect(restored.baseUrl, 'https://example.com');
    expect(restored.accessToken, 'access-1');
    expect(restored.refreshToken, 'refresh-1');
    expect(restored.expiresAt, DateTime.parse('2026-03-09T10:00:00Z'));
  });
}
