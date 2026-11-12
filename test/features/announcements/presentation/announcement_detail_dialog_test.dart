import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/announcement_detail_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/preview_helpers.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'small-screen detail dialog scrolls long content and opens link',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sessionStore = await buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      addTearDown(sessionStore.dispose);
      var openedLinks = 0;

      await pumpPreviewApp(
        tester,
        home: const _DetailOpener(),
        size: const Size(360, 640),
        theme: buildSakuraMobileThemeData(),
        platform: TargetPlatform.android,
        appPlatform: AppPlatform.mobile,
        bundle: bundle,
        extraOverrides: <Override>[
          externalUrlOpenerProvider.overrideWithValue((uri) async {
            openedLinks += 1;
            return true;
          }),
        ],
      );

      await tester.tap(find.byKey(const Key('open-announcement-detail')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('announcement-detail-dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('announcement-detail-link')), findsOneWidget);

      await tester.tap(find.byKey(const Key('announcement-detail-link')));
      await tester.pumpAndSettle();
      expect(openedLinks, 1);
    },
  );
}

class _DetailOpener extends StatelessWidget {
  const _DetailOpener();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('open-announcement-detail'),
        onPressed: () {
          showAnnouncementDetailDialog(
            context: context,
            announcement: AnnouncementDto(
              id: 'long-detail',
              level: AnnouncementLevel.warning,
              titleI18n: const <String, String>{
                'zh-CN': '长公告详情',
                'en': 'Long announcement',
              },
              bodyI18n: <String, String>{
                'zh-CN': List<String>.filled(40, '这是一段需要滚动查看的公告正文。').join('\n'),
                'en': List<String>.filled(
                  40,
                  'This is a long announcement body that needs scrolling.',
                ).join('\n'),
              },
              publishedAt: DateTime.now().toUtc(),
              link: 'https://example.test/announcement',
            ),
          );
        },
        child: const Text('open'),
      ),
    );
  }
}
