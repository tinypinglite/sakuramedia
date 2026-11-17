import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/critical_announcements_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

void main() {
  testWidgets('critical dialog blocks barrier dismissal until acknowledged', (
    tester,
  ) async {
    var acknowledged = 0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildSakuraDesktopThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                unawaited(
                  showAppAdaptiveModal<void>(
                    context: context,
                    modalKey: const Key('critical-announcements-dialog'),
                    barrierDismissible: false,
                    enableDrag: false,
                    showDesktopCloseButton: false,
                    showDrawerHandle: false,
                    builder: (_) => CriticalAnnouncementsDialog(
                      announcements: <AnnouncementDto>[
                        AnnouncementDto(
                          id: 'critical-1',
                          level: AnnouncementLevel.critical,
                          titleI18n: const <String, String>{
                            'zh-CN': '需要处理',
                            'en': 'Action required',
                          },
                          bodyI18n: const <String, String>{
                            'zh-CN': '请升级到最新版本。',
                            'en': 'Please upgrade.',
                          },
                          publishedAt: DateTime.utc(2026, 11, 12, 8),
                        ),
                      ],
                      onAcknowledge: () async {
                        acknowledged += 1;
                      },
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('critical-announcements-dialog')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('critical-announcements-dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('critical-announcement-acknowledge')),
    );
    await tester.pumpAndSettle();

    expect(acknowledged, 1);
    expect(
      find.byKey(const Key('critical-announcements-dialog')),
      findsNothing,
    );
  });
}
