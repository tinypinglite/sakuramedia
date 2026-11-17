import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';

void main() {
  test('withRange 支持设置、覆盖和清空热度指标', () {
    final filter = MovieInteractionFilter.initial
        .withRange(MovieInteractionMetric.heat, min: 1000)
        .withRange(MovieInteractionMetric.heat, min: 2000, max: 9000);

    expect(filter.rangeFor(MovieInteractionMetric.heat)?.min, 2000);
    expect(filter.rangeFor(MovieInteractionMetric.heat)?.max, 9000);
    expect(filter.activeMetricCount, 1);
    expect(filter.isDefault, isFalse);

    final cleared = filter.withRange(MovieInteractionMetric.heat);
    expect(cleared.rangeFor(MovieInteractionMetric.heat), isNull);
    expect(cleared.isDefault, isTrue);
  });

  test('addQueryParameters 只写热度 min/max，未设置的方向不发送', () {
    final parameters = <String, dynamic>{};
    MovieInteractionFilter.initial
        .withRange(MovieInteractionMetric.heat, min: 1000, max: 5000)
        .addQueryParameters(parameters);

    expect(parameters, <String, dynamic>{
      'heat_min': 1000,
      'heat_max': 5000,
    });
  });

  test('matches 按热度范围比较', () {
    final first = MovieInteractionFilter.initial.withRange(
      MovieInteractionMetric.heat,
      min: 1000,
    );
    final second = MovieInteractionFilter.initial.withRange(
      MovieInteractionMetric.heat,
      min: 1000,
    );

    expect(first.matches(second), isTrue);
    expect(
      first.matches(
        MovieInteractionFilter.initial.withRange(
          MovieInteractionMetric.heat,
          min: 1001,
        ),
      ),
      isFalse,
    );
  });
}
