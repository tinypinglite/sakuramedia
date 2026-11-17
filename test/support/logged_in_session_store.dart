import 'package:sakuramedia/core/session/session_store.dart';

/// 构造一个已登录的 in-memory [SessionStore]，供 API / widget 测试复用。
Future<SessionStore> buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
