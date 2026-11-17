import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

void main() {
  group('removeWhere', () {
    test('移除部分匹配：扣 total、重算 hasMore', () {
      final s = PagedListState<int>(
        items: const [1, 2, 3, 4],
        currentPage: 2,
        total: 10,
        hasMore: true,
        syncedAt: DateTime.parse('2026-01-01T00:00:00'),
      );
      final next = s.removeWhere((item) => item.isEven);
      expect(next.items, [1, 3]);
      expect(next.total, 8);
      expect(next.hasMore, isTrue);
      expect(next.currentPage, 2);
      expect(next.syncedAt, s.syncedAt);
    });

    test('全部移除：total 扣到 0、hasMore false、列表空', () {
      final s = PagedListState<int>(items: const [1, 2], total: 2, hasMore: false);
      final next = s.removeWhere((_) => true);
      expect(next.items, isEmpty);
      expect(next.total, 0);
      expect(next.hasMore, isFalse);
    });

    test('移除后恰满：hasMore false', () {
      final s = PagedListState<int>(items: const [1, 2, 3], total: 3, hasMore: false);
      final next = s.removeWhere((item) => item == 3);
      expect(next.items, [1, 2]);
      expect(next.total, 2);
      expect(next.hasMore, isFalse);
    });

    test('total 不足扣（total=0 边界 clamp 不为负）', () {
      final s = PagedListState<int>(items: const [1], total: 0, hasMore: false);
      final next = s.removeWhere((_) => true);
      expect(next.total, 0);
      expect(next.hasMore, isFalse);
    });

    test('无匹配：原样返回同一实例', () {
      final s = PagedListState<int>(items: const [1, 2], total: 2);
      final next = s.removeWhere((item) => item > 100);
      expect(identical(next, s), isTrue);
    });

    test('空列表 removeWhere 不抛且保持空', () {
      final s = PagedListState<int>(items: const [], total: 0);
      final next = s.removeWhere((item) => item == 1);
      expect(next.items, isEmpty);
      expect(next.total, 0);
    });
  });

  group('patchWhere', () {
    test('命中首个匹配项并替换，total/hasMore 不动', () {
      final s = PagedListState<int>(
        items: const [1, 2, 3],
        total: 10,
        hasMore: true,
      );
      final next = s.patchWhere((item) => item == 2, (_) => 20);
      expect(next.items, [1, 20, 3]);
      expect(next.total, 10);
      expect(next.hasMore, isTrue);
    });

    test('只替换第一个匹配项', () {
      final s = PagedListState<int>(items: const [2, 2, 3], total: 3);
      final next = s.patchWhere((item) => item == 2, (_) => 0);
      expect(next.items, [0, 2, 3]);
    });

    test('无匹配：原样返回', () {
      final s = PagedListState<int>(items: const [1, 2], total: 2);
      final next = s.patchWhere((item) => item == 99, (_) => 0);
      expect(identical(next, s), isTrue);
    });
  });

  group('upsertFront', () {
    test('命中：原地替换，不改 total/hasMore', () {
      final s = PagedListState<int>(items: const [1, 2], total: 5, hasMore: true);
      final next = s.upsertFront(9, matches: (item) => item == 2);
      expect(next.items, [1, 9]);
      expect(next.total, 5);
      expect(next.hasMore, isTrue);
    });

    test('未命中：头部插入 + total+1 + 重算 hasMore', () {
      final s = PagedListState<int>(items: const [1, 2], total: 2, hasMore: false);
      final next = s.upsertFront(0, matches: (item) => item == 99);
      expect(next.items, [0, 1, 2]);
      expect(next.total, 3);
      expect(next.hasMore, isFalse);
    });

    test('未命中且还有更多页：hasMore 保持 true', () {
      final s = PagedListState<int>(items: const [1, 2], total: 10, hasMore: true);
      final next = s.upsertFront(0, matches: (item) => item == 99);
      expect(next.items, [0, 1, 2]);
      expect(next.total, 11);
      expect(next.hasMore, isTrue);
    });

    test('空列表未命中：插入唯一项 total=1 hasMore=false', () {
      final s = PagedListState<int>(items: const [], total: 0);
      final next = s.upsertFront(7, matches: (item) => item == 1);
      expect(next.items, [7]);
      expect(next.total, 1);
      expect(next.hasMore, isFalse);
    });
  });

  group('不可变契约', () {
    test('三个原语产出的 items 都是 unmodifiable', () {
      final s = PagedListState<int>(items: const [1, 2, 3], total: 5);
      expect(() => s.removeWhere((item) => item == 1).items.add(9),
          throwsUnsupportedError);
      expect(() => s.patchWhere((item) => item == 1, (_) => 0).items.add(9),
          throwsUnsupportedError);
      expect(
        () => s.upsertFront(0, matches: (item) => false).items.add(9),
        throwsUnsupportedError,
      );
    });
  });
}
