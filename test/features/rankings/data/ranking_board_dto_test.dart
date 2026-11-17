import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('ranking period labels come from the language pack', () {
    final zh = AppLocalizationsZh();
    expect(rankingPeriodLabel('daily', zh), zh.rankingPeriodDaily);
    expect(rankingPeriodLabel('weekly', zh), zh.rankingPeriodWeekly);
    expect(rankingPeriodLabel('monthly', zh), zh.rankingPeriodMonthly);
    expect(rankingPeriodLabel('all', zh), zh.rankingPeriodAll);
    expect(rankingPeriodLabel('censored', zh), zh.rankingPeriodCensored);
    expect(rankingPeriodLabel('uncensored', zh), zh.rankingPeriodUncensored);
    expect(rankingPeriodLabel('fc2', zh), 'FC2');
    expect(rankingPeriodLabel('2026', zh), zh.rankingPeriodYear('2026'));
  });

  test('unknown periods pass through unchanged', () {
    final zh = AppLocalizationsZh();
    expect(rankingPeriodLabel('', zh), '');
    expect(rankingPeriodLabel('custom', zh), 'custom');
  });
}
