import 'package:flutter/foundation.dart';

/// 我的切片列表的筛选值对象。目前只有排序字段，值对象化是为了套用
/// `FilterablePagedAsyncNotifierMixin`（`F` 必须是不可变可 `==` 值对象）。
@immutable
class ClipsFilter {
  const ClipsFilter({this.sort = defaultSort});

  static const String defaultSort = 'created_at:desc';

  final String sort;

  bool get isDefault => sort == defaultSort;

  ClipsFilter copyWith({String? sort}) {
    return ClipsFilter(sort: sort ?? this.sort);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipsFilter && other.sort == sort);

  @override
  int get hashCode => sort.hashCode;
}
