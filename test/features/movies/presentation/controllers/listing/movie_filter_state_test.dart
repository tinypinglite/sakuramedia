import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

/// 中日韩统一表意文字，用于判定「英文界面漏出中文」。
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

MovieInteractionFilter _range(
  MovieInteractionMetric metric, {
  num? min,
  num? max,
}) {
  return MovieInteractionFilter.initial.withRange(metric, min: min, max: max);
}

void main() {
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  group('MovieStatusFilter', () {
    test('unsubscribed 映射后端 status 枚举值', () {
      expect(MovieStatusFilter.unsubscribed.apiValue, 'unsubscribed');
    });

    test('状态文案随语言切换且能区分订阅态', () {
      final enLabel = MovieStatusFilter.subscribed.labelWith(en);
      final zhSubscribed = MovieStatusFilter.subscribed.labelWith(zh);
      final zhUnsubscribed = MovieStatusFilter.unsubscribed.labelWith(zh);

      expect(_cjk.hasMatch(enLabel), isFalse);
      expect(_cjk.hasMatch(zhSubscribed), isTrue);
      expect(zhSubscribed, isNot(zhUnsubscribed));
    });
  });

  group('互动数滑块值 → 接口参数映射', () {
    test('下限 0 映射为不限，正值原样透传', () {
      expect(MovieInteractionMetric.heat.minFromSlider(0), isNull);
      expect(MovieInteractionMetric.heat.minFromSlider(1000), 1000);
      expect(MovieInteractionMetric.heat.minFromSlider(10839), 10839);
    });

    test('上限滑到顶映射为不限，未到顶原样透传', () {
      const maxValue = 10839.0;
      expect(
        MovieInteractionMetric.heat.maxFromSlider(maxValue, maxValue),
        isNull,
      );
      expect(
        MovieInteractionMetric.heat.maxFromSlider(maxValue - 1, maxValue),
        10838,
      );
      expect(MovieInteractionMetric.heat.maxFromSlider(5000, maxValue), 5000);
    });

    test('评分按 0.1 精度归一化', () {
      expect(MovieInteractionMetric.score.minFromSlider(8.04), 8.0);
      expect(MovieInteractionMetric.score.minFromSlider(8.06), 8.1);
      expect(MovieInteractionMetric.score.maxFromSlider(5, 5), isNull);
    });
  });

  group('movieInteractionRangeLabel', () {
    test('双边 / 单边 / 不限的文案', () {
      final both = movieInteractionRangeLabel(
        MovieInteractionMetric.heat,
        1000,
        5000,
        zh,
      );
      final lower = movieInteractionRangeLabel(
        MovieInteractionMetric.heat,
        1000,
        null,
        zh,
      );
      final upper = movieInteractionRangeLabel(
        MovieInteractionMetric.heat,
        null,
        5000,
        zh,
      );
      final unlimited = movieInteractionRangeLabel(
        MovieInteractionMetric.heat,
        null,
        null,
        zh,
      );

      // 四种边界形态必须能区分，且带上对应的数值。
      expect(<String>{both, lower, upper, unlimited}.length, 4);
      expect(both, contains('1000'));
      expect(both, contains('5000'));
      expect(lower, contains('1000'));
      expect(upper, contains('5000'));
      // 英文界面不得出现中文。
      expect(
        _cjk.hasMatch(
          movieInteractionRangeLabel(
            MovieInteractionMetric.heat,
            1000,
            5000,
            en,
          ),
        ),
        isFalse,
      );
    });
  });

  group('出演年龄滑块值 → 接口参数映射', () {
    test('下限 18 映射为不限，高于 18 原样透传', () {
      expect(movieActorAgeMinFromSlider(movieFilterActorAgeSliderMin), isNull);
      expect(movieActorAgeMinFromSlider(25), 25);
    });

    test('上限滑到顶 50 映射为不限，未到顶原样透传', () {
      expect(movieActorAgeMaxFromSlider(movieFilterActorAgeSliderMax), isNull);
      expect(movieActorAgeMaxFromSlider(49), 49);
      expect(movieActorAgeMaxFromSlider(30), 30);
    });
  });

  group('movieActorAgeRangeLabel', () {
    test('双边 / 单边 / 不限的文案', () {
      final both = movieActorAgeRangeLabel(18, 25, zh);
      final lower = movieActorAgeRangeLabel(30, null, zh);
      final upper = movieActorAgeRangeLabel(null, 25, zh);
      final unlimited = movieActorAgeRangeLabel(null, null, zh);

      expect(<String>{both, lower, upper, unlimited}.length, 4);
      expect(both, contains('18'));
      expect(both, contains('25'));
      expect(lower, contains('30'));
      expect(upper, contains('25'));

      final enLabel = movieActorAgeRangeLabel(18, 25, en);
      expect(_cjk.hasMatch(enLabel), isFalse);
    });
  });

  group('movieFilterYearsLabel', () {
    test('1 个直出，2 个顿号相连，3 个及以上折叠', () {
      final single = movieFilterYearsLabel(<int>{2024}, zh);
      final pair = movieFilterYearsLabel(<int>{2023, 2024}, zh);
      final folded = movieFilterYearsLabel(<int>{2022, 2024, 2023}, zh);

      expect(single, contains('2024'));
      expect(pair, contains('2023'));
      expect(pair, contains('2024'));
      // 3 个及以上折叠成「最新年份 + 总数」。
      expect(folded, contains('2024'));
      expect(folded, contains('3'));

      final enFolded = movieFilterYearsLabel(<int>{2022, 2024, 2023}, en);
      expect(_cjk.hasMatch(enFolded), isFalse);
    });

    test('空集返回空串', () {
      expect(movieFilterYearsLabel(const <int>{}, zh), '');
    });
  });

  group('MovieFilterState', () {
    test('初始状态不含互动数条件', () {
      const state = MovieFilterState.initial;
      expect(state.interaction.isDefault, isTrue);
      expect(state.hasInteractionRange, isFalse);
      expect(state.hasActiveFilters, isFalse);
      expect(state.triggerLabel(zh), '全部');
    });

    test('互动数条件影响 hasActiveFilters / hasInteractionRange / triggerLabel', () {
      final state = const MovieFilterState().copyWith(
        interaction: _range(MovieInteractionMetric.heat, min: 1000),
      );
      expect(state.hasInteractionRange, isTrue);
      expect(state.hasActiveFilters, isTrue);
      expect(state.triggerLabel(zh), '热度 ≥ 1000');

      final both = const MovieFilterState().copyWith(
        interaction: _range(MovieInteractionMetric.heat, min: 1000, max: 5000),
      );
      expect(both.triggerLabel(zh), '热度 1000 ~ 5000');
    });

    test('多个互动数指标折叠为数量摘要', () {
      final filter = _range(MovieInteractionMetric.heat, min: 1000)
          .withRange(MovieInteractionMetric.score, min: 8.0)
          .withRange(MovieInteractionMetric.commentCount, min: 10);
      final state = const MovieFilterState().copyWith(interaction: filter);

      expect(state.triggerLabel(zh), '互动数 · 3 项');
    });

    test('triggerLabel 优先级：年份 > 互动数 > 状态', () {
      final withYear = const MovieFilterState().copyWith(years: <int>{2024});
      expect(withYear.triggerLabel(zh), '2024');

      final withYearAndHeat = withYear.copyWith(
        interaction: _range(MovieInteractionMetric.heat, min: 1000),
      );
      expect(withYearAndHeat.triggerLabel(zh), '2024');

      final withHeatOnly = const MovieFilterState().copyWith(
        interaction: _range(MovieInteractionMetric.heat, max: 2000),
      );
      expect(withHeatOnly.triggerLabel(zh), '热度 ≤ 2000');
    });

    test('多选年份影响 hasActiveFilters / triggerLabel / matches', () {
      final multi = const MovieFilterState().copyWith(
        years: <int>{2022, 2024, 2023},
      );
      expect(multi.hasActiveFilters, isTrue);
      expect(multi.triggerLabel(zh), '2024 等 3 个年份');

      expect(
        multi.matches(const MovieFilterState(years: <int>{2024, 2023, 2022})),
        isTrue,
      );
      expect(
        multi.matches(const MovieFilterState(years: <int>{2024})),
        isFalse,
      );
      expect(multi.copyWith(years: const <int>{}).hasActiveFilters, isFalse);
    });

    test('copyWith 可显式清空年份条件', () {
      const withYears = MovieFilterState(years: <int>{2023, 2024});
      final cleared = withYears.copyWith(years: null);
      expect(cleared.years, isEmpty);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('copyWith 可清空互动数条件', () {
      final withHeat = MovieFilterState(
        interaction: _range(MovieInteractionMetric.heat, min: 1000, max: 5000),
      );
      final cleared = withHeat.copyWith(
        interaction: MovieInteractionFilter.initial,
      );
      expect(cleared.interaction.isDefault, isTrue);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('matches 比较互动数条件', () {
      const base = MovieFilterState();
      expect(base.matches(const MovieFilterState()), isTrue);
      expect(
        base.matches(
          MovieFilterState(
            interaction: _range(MovieInteractionMetric.heat, min: 1000),
          ),
        ),
        isFalse,
      );
      expect(
        MovieFilterState(
          interaction: _range(MovieInteractionMetric.score, min: 8.0),
        ).matches(
          MovieFilterState(
            interaction: _range(MovieInteractionMetric.score, min: 8.0),
          ),
        ),
        isTrue,
      );
    });

    test('初始状态不含出演年龄条件', () {
      const state = MovieFilterState.initial;
      expect(state.actorAgeMin, isNull);
      expect(state.actorAgeMax, isNull);
      expect(state.hasActorAgeRange, isFalse);
    });

    test('出演年龄条件影响 hasActiveFilters / hasActorAgeRange / triggerLabel', () {
      final state = const MovieFilterState().copyWith(actorAgeMax: 25);
      expect(state.hasActorAgeRange, isTrue);
      expect(state.hasActiveFilters, isTrue);
      expect(state.triggerLabel(zh), '≤ 25 岁');

      final both = const MovieFilterState().copyWith(
        actorAgeMin: 18,
        actorAgeMax: 25,
      );
      expect(both.triggerLabel(zh), '18 ~ 25 岁');
    });

    test('triggerLabel 优先级：年份 > 互动数 > 出演年龄 > 状态', () {
      final withAgeAndHeat = const MovieFilterState()
          .copyWith(actorAgeMax: 25)
          .copyWith(
            interaction: _range(MovieInteractionMetric.heat, min: 1000),
          );
      expect(withAgeAndHeat.triggerLabel(zh), '热度 ≥ 1000');

      final withAgeAndYear = const MovieFilterState()
          .copyWith(actorAgeMax: 25)
          .copyWith(years: <int>{2024});
      expect(withAgeAndYear.triggerLabel(zh), '2024');
    });

    test('copyWith 可显式清空出演年龄条件', () {
      const withAge = MovieFilterState(actorAgeMin: 20, actorAgeMax: 25);
      final cleared = withAge.copyWith(actorAgeMin: null, actorAgeMax: null);
      expect(cleared.actorAgeMin, isNull);
      expect(cleared.actorAgeMax, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('matches 比较出演年龄条件', () {
      const base = MovieFilterState();
      expect(base.matches(const MovieFilterState(actorAgeMax: 25)), isFalse);
      expect(
        const MovieFilterState(
          actorAgeMin: 20,
          actorAgeMax: 25,
        ).matches(const MovieFilterState(actorAgeMin: 20, actorAgeMax: 25)),
        isTrue,
      );
    });

    test('媒体文件标签影响摘要、匹配、重置与保持排序', () {
      const filter = MovieFilterState(
        mediaTagIds: <int>[3, 8],
        mediaTagMatch: TagMatchMode.and,
        sortField: MovieSortField.heat,
      );
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.triggerLabel(zh), '全部 · 文件标签 2');
      expect(
        filter.matches(
          const MovieFilterState(
            mediaTagIds: <int>[3, 8],
            mediaTagMatch: TagMatchMode.and,
            sortField: MovieSortField.heat,
          ),
        ),
        isTrue,
      );
      expect(
        filter.matches(
          const MovieFilterState(
            mediaTagIds: <int>[3, 8],
            mediaTagMatch: TagMatchMode.or,
          ),
        ),
        isFalse,
      );

      final reset = filter.resetFilters();
      expect(reset.mediaTagIds, isEmpty);
      expect(reset.mediaTagMatch, TagMatchMode.or);
      expect(reset.sortField, MovieSortField.heat);
      expect(reset.hasActiveFilters, isFalse);
    });
  });

  group('排序与筛选分离', () {
    test('hasActiveFilters 不含排序', () {
      const sorted = MovieFilterState(
        sortField: MovieSortField.heat,
        sortDirection: SortDirection.asc,
      );
      expect(sorted.hasActiveFilters, isFalse);
    });

    test('resetFilters 清空筛选但保留排序', () {
      final state = MovieFilterState.initial
          .copyWith(
            sortField: MovieSortField.heat,
            sortDirection: SortDirection.asc,
          )
          .copyWith(status: MovieStatusFilter.subscribed);

      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, MovieSortField.heat);
      expect(reset.sortDirection, SortDirection.asc);

      final defaultSortReset = const MovieFilterState(
        status: MovieStatusFilter.subscribed,
      ).resetFilters();
      expect(defaultSortReset.hasActiveFilters, isFalse);
    });
  });

  group('我的评分排序', () {
    test('总分排序使用 my_score', () {
      const filter = MovieFilterState(sortField: MovieSortField.myScore);
      expect(filter.sortExpression, 'my_score:desc');
    });

    test('维度排序覆盖普通排序字段，可清除', () {
      final filter = const MovieFilterState(
        sortField: MovieSortField.myScore,
      ).copyWith(dimensionSortId: 7, sortDirection: SortDirection.asc);
      expect(filter.sortExpression, 'dimension_7:asc');
      expect(
        filter.copyWith(dimensionSortId: null).sortExpression,
        'my_score:asc',
      );
    });
  });
}
