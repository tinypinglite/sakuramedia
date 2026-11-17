import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  group('ActorSortField', () {
    test('可播放影片数映射后端排序字段', () {
      expect(
        ActorSortField.playableMovieCount.apiValue,
        'playable_movie_count',
      );
      expect(
        ActorSortField.playableMovieCount.label(AppLocalizationsZh()),
        '可播放影片数',
      );
    });
  });

  group('ActorFilterState', () {
    test('初始状态不搜索、不筛可播放且为默认态', () {
      const state = ActorFilterState.initial;
      expect(state.query, isNull);
      expect(state.hasPlayableMovies, isFalse);
      expect(state.hasActiveFilters, isFalse);
    });

    test('关键词与可播放筛选影响 hasActiveFilters', () {
      expect(const ActorFilterState(query: '三上').hasActiveFilters, isTrue);
      expect(
        const ActorFilterState(hasPlayableMovies: true).hasActiveFilters,
        isTrue,
      );
    });

    test('copyWith 可显式清空关键词', () {
      const withQuery = ActorFilterState(query: '三上');
      expect(withQuery.copyWith().query, '三上');
      expect(withQuery.copyWith(query: null).query, isNull);
    });

    test('withSearchQuery 从默认「已订阅」开始搜索时放宽为全部', () {
      final next = ActorFilterState.initial.withSearchQuery('  三上  ');
      expect(next.query, '三上');
      expect(next.subscriptionStatus, ActorSubscriptionStatus.all);
    });

    test('withSearchQuery 开始搜索时保留显式选择的未订阅筛选', () {
      const state = ActorFilterState(
        subscriptionStatus: ActorSubscriptionStatus.unsubscribed,
      );
      final next = state.withSearchQuery('三上');
      expect(next.query, '三上');
      expect(next.subscriptionStatus, ActorSubscriptionStatus.unsubscribed);
    });

    test('withSearchQuery 搜索中继续输入不覆盖手动改过的筛选', () {
      const state = ActorFilterState(
        query: '三上',
        subscriptionStatus: ActorSubscriptionStatus.subscribed,
      );
      final next = state.withSearchQuery('三上悠亚');
      expect(next.query, '三上悠亚');
      expect(next.subscriptionStatus, ActorSubscriptionStatus.subscribed);
    });

    test('withSearchQuery 清空关键词只清 query，订阅筛选保持现状', () {
      const state = ActorFilterState(
        query: '三上',
        subscriptionStatus: ActorSubscriptionStatus.all,
      );
      final cleared = state.withSearchQuery('');
      expect(cleared.query, isNull);
      expect(cleared.subscriptionStatus, ActorSubscriptionStatus.all);
    });

    test('排序表达式包含可播放影片数', () {
      const state = ActorFilterState(
        sortField: ActorSortField.playableMovieCount,
      );
      expect(state.sortExpression, 'playable_movie_count:desc');
    });

    test('相等性包含关键词与可播放筛选', () {
      const base = ActorFilterState();
      expect(base == const ActorFilterState(), isTrue);
      expect(base == const ActorFilterState(query: '三上'), isFalse);
      expect(base == const ActorFilterState(hasPlayableMovies: true), isFalse);
      expect(
        base.hashCode ==
            const ActorFilterState(hasPlayableMovies: true).hashCode,
        isFalse,
      );
    });
  });

  group('排序与筛选分离', () {
    test('hasActiveFilters 不含排序', () {
      const state = ActorFilterState(
        sortField: ActorSortField.age,
        sortDirection: SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
    });

    test('resetFilters 清空筛选但保留排序', () {
      const state = ActorFilterState(
        gender: ActorGender.female,
        sortField: ActorSortField.heightCm,
        sortDirection: SortDirection.asc,
      );
      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, ActorSortField.heightCm);
      expect(reset.sortDirection, SortDirection.asc);
    });

    test('isSearching 只看关键词，relevance 只看默认字段', () {
      expect(ActorFilterState.initial.isSearching, isFalse);
      expect(const ActorFilterState(query: '三上').isSearching, isTrue);
      expect(const ActorFilterState(query: '三上').usesRelevanceSort, isTrue);
      expect(
        const ActorFilterState(
          query: '三上',
          sortField: ActorSortField.movieCount,
        ).usesRelevanceSort,
        isFalse,
      );
    });
  });
}
