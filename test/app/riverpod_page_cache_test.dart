import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';

/// 真实 KeepAliveLink 的来源：autoDispose provider 在 build 里自持
/// `ref.keepAlive()`。link close（且无监听者）后 provider 被释放，再次 read
/// 触发重建、拿到新的 link 实例——以此验证「close 后状态被释放」。
final _linkA = Provider.autoDispose<KeepAliveLink>((ref) => ref.keepAlive());
final _linkB = Provider.autoDispose<KeepAliveLink>((ref) => ref.keepAlive());
final _linkC = Provider.autoDispose<KeepAliveLink>((ref) => ref.keepAlive());

/// 给 autoDispose 调度一个 flush 窗口，让 close 后的释放落定。
Future<void> pumpMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late RiverpodPageCache cache;

  setUp(() {
    cache = RiverpodPageCache(maxEntries: 2);
    addTearDown(cache.dispose);
  });

  test('obtain 未命中：收集 resolveLinks 的 link 并缓存', () {
    final handle = cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[]);
    expect(handle.key, 'a');
    expect(handle.links, isEmpty);
    expect(handle.refCount, 1);
    expect(cache.size, 1);
  });

  test('obtain 命中同 key：MRU 重放、同一 handle、引用计数累加', () {
    final first = cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[]);
    final second = cache.obtain(
      key: 'a',
      resolveLinks: () => <KeepAliveLink>[],
    );
    expect(identical(first, second), isTrue);
    expect(first.refCount, 2);
    expect(cache.size, 1);

    first.release();
    expect(first.refCount, 1);
    second.release();
    expect(first.refCount, 0);
    // release 不 close link：缓存条目仍在。
    expect(cache.size, 1);
  });

  test('驱逐：超上限踢最旧条目并 close 其 link（真实 link 生效）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkA = container.read(_linkA);
    final linkB = container.read(_linkB);
    // keepAlive 未 close：同一实例稳定。
    expect(identical(container.read(_linkA), linkA), isTrue);

    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.obtain(key: 'b', resolveLinks: () => <KeepAliveLink>[linkB]);
    expect(cache.size, 2);

    // 第三条目触发驱逐：最旧（a）被踢、link 被 close。
    final linkC = container.read(_linkC);
    cache.obtain(key: 'c', resolveLinks: () => <KeepAliveLink>[linkC]);
    expect(cache.size, 2);

    // a 的 link 已 close：provider 被释放，再次 read 重建为新实例。
    await pumpMicrotasks();
    expect(identical(container.read(_linkA), linkA), isFalse);
    // b / c 的 link 未 close：仍同实例。
    expect(identical(container.read(_linkB), linkB), isTrue);
    expect(identical(container.read(_linkC), linkC), isTrue);
  });

  test('MRU 重放：再次 obtain 已存在的 key 改变驱逐顺序', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkA = container.read(_linkA);
    final linkB = container.read(_linkB);
    final linkC = container.read(_linkC);

    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.obtain(key: 'b', resolveLinks: () => <KeepAliveLink>[linkB]);
    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.obtain(key: 'c', resolveLinks: () => <KeepAliveLink>[linkC]);

    // MRU 顺序为 b（最旧）、a、c：再 obtain d 时被踢的是 b。
    expect(cache.size, 2);
    await pumpMicrotasks();
    expect(identical(container.read(_linkB), linkB), isFalse);
    // 命中过的 a / c 存活。
    expect(identical(container.read(_linkA), linkA), isTrue);
    expect(identical(container.read(_linkC), linkC), isTrue);
  });

  test('remove：立即 close 该 key 的 link', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkA = container.read(_linkA);
    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.remove('a');
    expect(cache.size, 0);

    await pumpMicrotasks();
    expect(identical(container.read(_linkA), linkA), isFalse);
  });

  test('clearAll：全部 link close、条目清空', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkA = container.read(_linkA);
    final linkB = container.read(_linkB);
    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.obtain(key: 'b', resolveLinks: () => <KeepAliveLink>[linkB]);

    cache.clearAll();
    expect(cache.size, 0);

    await pumpMicrotasks();
    expect(identical(container.read(_linkA), linkA), isFalse);
    expect(identical(container.read(_linkB), linkB), isFalse);
  });

  test('bindSessionStore：登出边沿自动清空全部 link', () async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    await sessionStore.saveTokens(
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final linkA = container.read(_linkA);

    cache.bindSessionStore(sessionStore);
    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    expect(cache.size, 1);

    await sessionStore.clearSession();
    expect(cache.size, 0);
    await pumpMicrotasks();
    expect(identical(container.read(_linkA), linkA), isFalse);
  });

  test('bindSessionStore：绑定即登出态时直接清空（无会话起步）', () async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final linkA = container.read(_linkA);

    cache.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    cache.bindSessionStore(sessionStore);
    expect(cache.size, 0);
    await pumpMicrotasks();
    expect(identical(container.read(_linkA), linkA), isFalse);
  });

  test('dispose：解绑会话监听并清空', () {
    final sessionStore = SessionStore.inMemory();
    final container = ProviderContainer();
    final linkA = container.read(_linkA);

    final standalone = RiverpodPageCache(maxEntries: 2);
    standalone.bindSessionStore(sessionStore);
    standalone.obtain(key: 'a', resolveLinks: () => <KeepAliveLink>[linkA]);
    expect(standalone.size, 1);

    standalone.dispose();
    sessionStore.dispose();
    container.dispose();
  });
}
