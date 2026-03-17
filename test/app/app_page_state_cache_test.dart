import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';

void main() {
  test('obtain returns cached entry for the same key', () {
    final cache = AppPageStateCache(maxEntries: 4);
    var createdCount = 0;

    final first = cache.obtain<_FakePageStateEntry>(
      key: 'desktop:movies:list',
      create: () {
        createdCount += 1;
        return _FakePageStateEntry();
      },
    );
    final second = cache.obtain<_FakePageStateEntry>(
      key: 'desktop:movies:list',
      create: () {
        createdCount += 1;
        return _FakePageStateEntry();
      },
    );

    expect(identical(first, second), isTrue);
    expect(createdCount, 1);
  });

  test('evicts least-recently-used entry and disposes it', () {
    final cache = AppPageStateCache(maxEntries: 2);
    final first = _FakePageStateEntry();
    final second = _FakePageStateEntry();
    final third = _FakePageStateEntry();

    cache.obtain<_FakePageStateEntry>(key: 'key-1', create: () => first);
    cache.obtain<_FakePageStateEntry>(key: 'key-2', create: () => second);
    cache.obtain<_FakePageStateEntry>(key: 'key-3', create: () => third);

    expect(cache.size, 2);
    expect(first.isDisposed, isTrue);
    expect(second.isDisposed, isFalse);
    expect(third.isDisposed, isFalse);
  });

  test('clears all cached states when session is cleared', () async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );

    final cache = AppPageStateCache(maxEntries: 4)
      ..bindSessionStore(sessionStore);
    final first = _FakePageStateEntry();
    final second = _FakePageStateEntry();

    cache.obtain<_FakePageStateEntry>(
      key: 'desktop:actors:list',
      create: () => first,
    );
    cache.obtain<_FakePageStateEntry>(
      key: 'desktop:image-search',
      create: () => second,
    );
    expect(cache.size, 2);

    await sessionStore.clearSession();

    expect(cache.size, 0);
    expect(first.isDisposed, isTrue);
    expect(second.isDisposed, isTrue);
  });
}

class _FakePageStateEntry implements AppPageStateEntry {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
  }
}
