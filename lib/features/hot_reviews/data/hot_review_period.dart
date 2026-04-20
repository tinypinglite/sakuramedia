enum HotReviewPeriod {
  weekly(apiValue: 'weekly', label: '本周'),
  monthly(apiValue: 'monthly', label: '本月'),
  quarterly(apiValue: 'quarterly', label: '季度'),
  yearly(apiValue: 'yearly', label: '年度'),
  all(apiValue: 'all', label: '总榜');

  const HotReviewPeriod({required this.apiValue, required this.label});

  final String apiValue;
  final String label;
}
