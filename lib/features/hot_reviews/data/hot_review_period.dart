enum HotReviewPeriod {
  weekly(apiValue: 'weekly', label: '周'),
  monthly(apiValue: 'monthly', label: '月'),
  quarterly(apiValue: 'quarterly', label: '季'),
  yearly(apiValue: 'yearly', label: '年'),
  all(apiValue: 'all', label: '总');

  const HotReviewPeriod({required this.apiValue, required this.label});

  final String apiValue;
  final String label;
}
