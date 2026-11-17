import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 订阅管理列表的筛选状态（不可变值对象）。
///
/// 三个维度分属**两个入口**：
/// - [status] 由顶部状态分段签驱动（它自带计数、是页面的一级维度）；
/// - [sort] / [search] 收口在顶栏筛选面板里（桌面浮层 / 移动抽屉同一份内容）。
///
/// 拆成两个入口但只有**一个**值对象：三者最终拼进同一个查询，分成两份状态会让
/// 「改了哪个要 reload」变得含糊。
@immutable
class MovieSubscriptionFilterState {
  const MovieSubscriptionFilterState({
    this.status,
    this.sort = MovieSubscriptionSort.subscribedAtDesc,
    this.search = '',
  });

  /// 默认落在「缺资源」而不是「全部」。
  ///
  /// 订阅是长期意图、只增不减，`imported` 往往占九成以上——默认展示全部等于让用户
  /// 自己去一千多条里找那几十条卡住的。后端文档也明确要求默认视图是「需要关注
  /// 的」。这里取三个待办态里最大也最常见的一个；另两个（已放弃 / 查询出错）由
  /// 分段签的警示色角标拉住注意力。
  static const MovieSubscriptionFilterState initial =
      MovieSubscriptionFilterState(status: MovieSubscriptionStatus.missing);

  /// `null` 表示「全部」，不下发 status 参数。
  final MovieSubscriptionStatus? status;
  final MovieSubscriptionSort sort;

  /// 番号 / 标题 / 中文标题模糊匹配；空串表示不搜索。
  final String search;

  MovieSubscriptionFilterState copyWith({
    Object? status = _kSentinel,
    MovieSubscriptionSort? sort,
    String? search,
  }) {
    return MovieSubscriptionFilterState(
      // status 可空且「置为 null」有独立语义（= 全部），所以走哨兵而非 `??`。
      status: identical(status, _kSentinel)
          ? this.status
          : status as MovieSubscriptionStatus?,
      sort: sort ?? this.sort,
      search: search ?? this.search,
    );
  }

  String get trimmedSearch => search.trim();

  bool get hasSearch => trimmedSearch.isNotEmpty;

  /// 排序字段与方向，由完整的 [sort] 值派生，供排序面板使用。
  MovieSubscriptionSortField get sortField => sort.field;
  SortDirection get sortDirection => sort.direction;

  MovieSubscriptionFilterState withSortField(
    MovieSubscriptionSortField field,
  ) => copyWith(sort: field.withDirection(sortDirection));

  MovieSubscriptionFilterState withSortDirection(SortDirection direction) =>
      copyWith(sort: sortField.withDirection(direction));

  /// 是否存在生效的筛选条件。**不含排序**。
  bool get hasActiveFilters => hasSearch;

  /// 筛选面板（仅搜索）是否停在默认值——决定面板底部「重置」是否可点。
  ///
  /// 刻意**不含 [status]**：状态是分段签，重置面板不该把用户切走的签也拨回去。
  bool get isPanelDefault => !hasActiveFilters;

  /// 只清面板维度，保留当前分段签与排序。
  MovieSubscriptionFilterState resetPanel() {
    return MovieSubscriptionFilterState(status: status, sort: sort);
  }

  /// 顶栏筛选入口里的摘要文案。排序由独立入口表达，这里只报搜索。
  ///
  /// 调用方负责传入当前语言的 [AppLocalizations]。
  String triggerLabel(AppLocalizations l10n) => hasSearch
      ? l10n.subscriptionFilterTriggerSearch(trimmedSearch)
      : l10n.subscriptionFilterTriggerAll;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieSubscriptionFilterState &&
        other.status == status &&
        other.sort == sort &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(status, sort, search);
}

const Object _kSentinel = Object();
