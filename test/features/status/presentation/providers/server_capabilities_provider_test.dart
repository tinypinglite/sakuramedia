import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  for (final flags in [(false, false), (true, false), (true, true)]) {
    test('server capabilities $flags gate similar movie requests', () async {
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://example.test');
      await session.saveTokens(accessToken: 'test', refreshToken: 'test', expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final bundle = await createTestApiBundle(session);
      final container = ProviderContainer(overrides: bundle.riverpodOverrides());
      addTearDown(() { container.dispose(); bundle.dispose(); session.dispose(); });
      bundle.adapter.enqueueJson(method: 'GET', path: '/status/capabilities', body: {'movie_similarity': flags.$1, 'image_search': flags.$2});
      final capabilities = await container.read(serverCapabilitiesProvider.future);
      expect(capabilities.movieSimilarity, flags.$1);
      expect(capabilities.imageSearch, flags.$2);
      await container.read(movieDetailProvider('ABC-001').notifier).retryLoadSimilarMovies();
      expect(bundle.adapter.requests.where((r) => r.path.contains('/similar')).length, flags.$1 ? 1 : 0);
    });
  }

  test('404 preserves old server capabilities; switching server clears snapshot', () async {
    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://old.example.test');
    await session.saveTokens(accessToken: 'test', refreshToken: 'test', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    final bundle = await createTestApiBundle(session);
    final container = ProviderContainer(overrides: bundle.riverpodOverrides());
    addTearDown(() { container.dispose(); bundle.dispose(); session.dispose(); });
    bundle.adapter.enqueueJson(method: 'GET', path: '/status/capabilities', statusCode: 404);
    expect((await container.read(serverCapabilitiesProvider.future)).imageSearch, isTrue);
    bundle.adapter.enqueueJson(method: 'GET', path: '/status/capabilities', body: {'movie_similarity': false, 'image_search': false});
    await session.saveBaseUrl('https://new.example.test');
    expect((await container.read(serverCapabilitiesProvider.future)).imageSearch, isFalse);
    expect(bundle.adapter.hitCount('GET', '/status/capabilities'), 2);
  });

  test('network error does not advertise enabled capabilities', () async {
    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://example.test');
    await session.saveTokens(accessToken: 'test', refreshToken: 'test', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    final bundle = await createTestApiBundle(session);
    final container = ProviderContainer(overrides: bundle.riverpodOverrides());
    addTearDown(() { container.dispose(); bundle.dispose(); session.dispose(); });
    bundle.adapter.enqueueJson(method: 'GET', path: '/status/capabilities', statusCode: 503);
    await expectLater(container.read(serverCapabilitiesProvider.future), throwsA(anything));
    expect(container.read(imageSearchEnabledProvider), isFalse);
  });
}
