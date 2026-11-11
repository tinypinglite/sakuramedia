import 'package:sakuramedia/l10n/app_localizations.dart';

class RankingBoardDto {
  const RankingBoardDto({
    required this.sourceKey,
    required this.boardKey,
    required this.name,
    required this.supportedPeriods,
    required this.defaultPeriod,
  });

  final String sourceKey;
  final String boardKey;
  final String name;
  final List<String> supportedPeriods;
  final String? defaultPeriod;

  factory RankingBoardDto.fromJson(Map<String, dynamic> json) {
    final rawSupportedPeriods = json['supported_periods'];
    final supportedPeriods = rawSupportedPeriods is List
        ? rawSupportedPeriods
              .whereType<Object?>()
              .map((item) => item?.toString() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final defaultPeriod = json['default_period'] as String?;
    return RankingBoardDto(
      sourceKey: json['source_key'] as String? ?? '',
      boardKey: json['board_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      supportedPeriods: supportedPeriods,
      defaultPeriod: defaultPeriod != null && defaultPeriod.isNotEmpty
          ? defaultPeriod
          : null,
    );
  }
}

/// 榜单周期的展示文案，按当前语言渲染。
String rankingPeriodLabel(String period, AppLocalizations l10n) {
  switch (period) {
    case 'daily':
      return l10n.rankingPeriodDaily;
    case 'weekly':
      return l10n.rankingPeriodWeekly;
    case 'monthly':
      return l10n.rankingPeriodMonthly;
    // 部分来源用固定子榜和年份作为周期。
    case 'all':
      return l10n.rankingPeriodAll;
    case 'censored':
      return l10n.rankingPeriodCensored;
    case 'uncensored':
      return l10n.rankingPeriodUncensored;
    case 'fc2':
      return 'FC2';
  }
  if (period.length == 4 && int.tryParse(period) != null) {
    return l10n.rankingPeriodYear(period);
  }
  return period;
}
