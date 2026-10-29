import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_candidate_selection_summary.dart';

void main() {
  testWidgets('shows recommendation and preferred group badges', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadCandidateSelectionEvaluationDto(
        eligible: true,
        matchedPreferredGroupLabel: '中文字幕',
        selectionRank: 1,
        withinAttemptLimit: true,
      ),
    );

    expect(find.text('策略推荐 #1'), findsOneWidget);
    expect(find.text('偏好：中文字幕'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppBadge &&
            widget.tone == AppBadgeTone.primary &&
            widget.label == '策略推荐 #1',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppBadge &&
            widget.tone == AppBadgeTone.neutral &&
            widget.label == '偏好：中文字幕',
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks eligible candidates outside the automatic attempt limit', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadCandidateSelectionEvaluationDto(
        eligible: true,
        selectionRank: 6,
        withinAttemptLimit: false,
      ),
    );

    expect(find.text('策略推荐 #6'), findsNothing);
    expect(find.text('符合策略 #6，但超出自动尝试范围'), findsOneWidget);
    expect(find.text('自动下载会跳过此资源，但你仍可手动提交。'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppBadge &&
            widget.tone == AppBadgeTone.warning &&
            widget.label == '符合策略 #6，但超出自动尝试范围',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows localized rejection reasons and manual-submit hint', (
    tester,
  ) async {
    await _pump(
      tester,
      const DownloadCandidateSelectionEvaluationDto(
        eligible: false,
        rejectionReasons: <DownloadSelectionRejectionDto>[
          DownloadSelectionRejectionDto(
            code: 'excluded_term',
            message: '命中排除词 sample',
            term: 'sample',
          ),
        ],
      ),
    );

    expect(find.text('不符合选种策略'), findsOneWidget);
    expect(find.text('· 命中排除词 sample'), findsOneWidget);
    expect(find.text('自动下载会跳过此资源，但你仍可手动提交。'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppBadge &&
            widget.tone == AppBadgeTone.warning &&
            widget.label == '不符合选种策略',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  DownloadCandidateSelectionEvaluationDto evaluation,
) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      theme: sakuraThemeData,
      home: Scaffold(
        body: DownloadCandidateSelectionSummary(evaluation: evaluation),
      ),
    ),
  );
}
