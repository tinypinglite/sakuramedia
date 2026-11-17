import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  group('MovieSubscriptionFilterState 排序与筛选分离', () {
    test('默认排序状态与面板默认态', () {
      const state = MovieSubscriptionFilterState.initial;
      expect(state.sortField, MovieSubscriptionSortField.subscribedAt);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.hasActiveFilters, isFalse);
      expect(state.isPanelDefault, isTrue);
      expect(state.triggerLabel(AppLocalizationsZh()), '全部');
    });

    test('只改排序不会让搜索筛选变成「已筛选」', () {
      final state = MovieSubscriptionFilterState.initial.withSortDirection(
        SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
      expect(state.isPanelDefault, isTrue);
      expect(state.triggerLabel(AppLocalizationsZh()), '全部');
      expect(state.sortDirection, SortDirection.asc);
    });

    test('搜索才是筛选摘要', () {
      final state = MovieSubscriptionFilterState.initial.copyWith(
        search: '  ABP-123 ',
      );
      expect(state.hasActiveFilters, isTrue);
      expect(state.triggerLabel(AppLocalizationsZh()), '搜索「ABP-123」');
    });

    test('resetPanel 保留搜索之外的排序', () {
      final state = MovieSubscriptionFilterState.initial
          .withSortField(MovieSubscriptionSortField.releaseDate)
          .withSortDirection(SortDirection.asc)
          .copyWith(search: 'ABP');
      final reset = state.resetPanel();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, MovieSubscriptionSortField.releaseDate);
      expect(reset.sortDirection, SortDirection.asc);
    });

    test('没找到次数只支持降序', () {
      final state = MovieSubscriptionFilterState.initial.withSortField(
        MovieSubscriptionSortField.attemptCount,
      );
      expect(state.sortDirection, SortDirection.desc);
      expect(
        state.withSortDirection(SortDirection.asc).sortDirection,
        SortDirection.desc,
      );
      expect(
        MovieSubscriptionSortField.attemptCount.supportsDirection,
        isFalse,
      );
    });
  });
}
