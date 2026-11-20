import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/media-tags',
      body: <dynamic>[],
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders all/status chips without duplicate keys', (
    tester,
  ) async {
    await pumpPreviewApp(
      tester,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: PlaylistFilterSectionGroup(
              filterState: PlaylistFilterState.initial,
              onChanged: _ignoreFilterChange,
            ),
          ),
        ),
      ),
      size: const Size(900, 1200),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('playlist-filter-status-all')), findsOneWidget);
    expect(
      find.byKey(const Key('playlist-filter-watch-status-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('playlist-filter-status-playable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('playlist-filter-watch-status-watched')),
      findsOneWidget,
    );
  });
}

void _ignoreFilterChange(PlaylistFilterState _) {}
