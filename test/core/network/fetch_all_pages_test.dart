import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/fetch_all_pages.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';

PaginatedResponseDto<int> page(int p, List<int> items, int total) =>
    PaginatedResponseDto<int>(
      items: items,
      page: p,
      pageSize: 2,
      total: total,
    );

void main() {
  test('并发翻页拉全部并按页序拼接', () async {
    final pages = <int, PaginatedResponseDto<int>>{
      1: page(1, <int>[1, 2], 5),
      2: page(2, <int>[3, 4], 5),
      3: page(3, <int>[5], 5),
    };
    final fetched = <int>[];

    final result = await fetchAllPagesConcurrently<int, int>(
      fetchPage: (p) async {
        fetched.add(p);
        return pages[p]!;
      },
      extractItems: (response) => response.items,
      pageSize: 2,
    );

    expect(result, <int>[1, 2, 3, 4, 5]);
    // 第 1 页先取，其余页（2、3）落在同一并发批次。
    expect(fetched, containsAll(<int>[1, 2, 3]));
    expect(fetched.first, 1);
  });

  test('首页即取满 total 时不再翻页', () async {
    var calls = 0;
    final result = await fetchAllPagesConcurrently<int, int>(
      fetchPage: (p) async {
        calls++;
        return page(1, <int>[1, 2], 2);
      },
      extractItems: (response) => response.items,
      pageSize: 2,
    );

    expect(result, <int>[1, 2]);
    expect(calls, 1);
  });

  test('提供 keyOf 时跨页重复项按出现顺序去重（保留首次）', () async {
    // 模拟并发增删导致页窗口错位：第 2 页与第 1 页重叠出现 id 2。
    final pages = <int, PaginatedResponseDto<int>>{
      1: page(1, <int>[1, 2], 4),
      2: page(2, <int>[2, 3], 4),
    };

    final result = await fetchAllPagesConcurrently<int, int>(
      fetchPage: (p) async => pages[p]!,
      extractItems: (response) => response.items,
      pageSize: 2,
      keyOf: (item) => item,
    );

    expect(result, <int>[1, 2, 3]);
  });
}
