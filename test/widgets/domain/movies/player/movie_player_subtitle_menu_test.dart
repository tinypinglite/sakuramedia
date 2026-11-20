import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/media/video/sakura_desktop_video_controls.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_subtitle_button.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget app(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: Scaffold(body: child),
      ),
    );
  }

  Widget desktopHarness({required Widget child, VoidCallback? onUnderlayTap}) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('movie-player-subtitle-test-underlay'),
            behavior: HitTestBehavior.opaque,
            onTap: onUnderlayTap,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SizedBox(width: 180, height: 40, child: child),
          ),
        ),
      ],
    );
  }

  MoviePlayerSubtitleState subtitleState() {
    return const MoviePlayerSubtitleState(
      options: <MoviePlayerSubtitleOption>[
        MoviePlayerSubtitleOption(
          subtitleId: 7,
          label: 'SSNI-644-2.srt',
          resolvedUrl: 'https://example.com/subtitle-2.vtt',
        ),
        MoviePlayerSubtitleOption(
          subtitleId: 8,
          label: 'SSNI-644-1.srt',
          resolvedUrl: 'https://example.com/subtitle-1.vtt',
        ),
      ],
      selectedSubtitleId: null,
      isLoading: false,
      fetchStatus: 'ready',
      errorMessage: null,
    );
  }

  MoviePlayerSubtitleButton subtitleButton({
    ValueNotifier<MoviePlayerSubtitleState>? subtitleStateNotifier,
    ValueNotifier<bool>? isApplyingNotifier,
    Future<void> Function(int? subtitleId)? onSubtitleSelected,
  }) {
    return MoviePlayerSubtitleButton(
      subtitleStateListenable:
          subtitleStateNotifier ??
          ValueNotifier<MoviePlayerSubtitleState>(subtitleState()),
      isApplyingListenable: isApplyingNotifier ?? ValueNotifier<bool>(false),
      onSubtitleSelected: onSubtitleSelected ?? (_) async {},
      onReloadRequested: () async {},
    );
  }

  testWidgets('桌面字幕设置在浮层内完成，滑杆和恢复默认实时生效', (tester) async {
    var underlayTaps = 0;
    await tester.pumpWidget(
      app(
        desktopHarness(
          onUnderlayTap: () => underlayTaps++,
          child: subtitleButton(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();
    expect(
      AppSurfaceStyleScope.of(
        tester.element(find.byKey(const Key('movie-player-subtitle-menu'))),
      ),
      AppSurfaceStyle.flat,
    );
    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-menu-settings')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-player-subtitle-settings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-player-subtitle-menu-item-7')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-player-subtitle-settings-modal')),
      findsNothing,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('movie-player-subtitle-settings'))),
      listen: false,
    );
    await tester.drag(
      find.byKey(const Key('movie-player-subtitle-settings-scale-slider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(playerSubtitlePreferenceControllerProvider).value!.scale,
      isNot(1.0),
    );

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-settings-reset')),
    );
    await tester.pumpAndSettle();
    expect(
      container
          .read(playerSubtitlePreferenceControllerProvider)
          .value!
          .isDefault,
      isTrue,
    );
    expect(underlayTaps, 0);

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-settings-back')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-player-subtitle-menu-item-7')),
      findsOneWidget,
    );
  });

  testWidgets('桌面字幕浮层打开时锁定控制条，关闭后释放', (tester) async {
    var acquireCount = 0;
    var releaseCount = 0;
    final subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      subtitleState(),
    );
    final applyingNotifier = ValueNotifier<bool>(false);
    addTearDown(subtitleStateNotifier.dispose);
    addTearDown(applyingNotifier.dispose);

    await tester.pumpWidget(
      app(
        Center(
          child: SakuraDesktopVideoControlsOverlayLockScope(
            acquire: () => acquireCount++,
            release: () => releaseCount++,
            child: SizedBox(
              width: 180,
              height: 40,
              child: subtitleButton(
                subtitleStateNotifier: subtitleStateNotifier,
                isApplyingNotifier: applyingNotifier,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();
    expect(acquireCount, 1);
    expect(releaseCount, 0);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
    expect(releaseCount, 1);

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();
    expect(acquireCount, 2);
    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(releaseCount, 2);
  });

  testWidgets('桌面字幕菜单选择字幕仍会回传并关闭浮层', (tester) async {
    int? selectedSubtitleId;
    await tester.pumpWidget(
      app(
        Center(
          child: SizedBox(
            width: 180,
            height: 40,
            child: subtitleButton(
              onSubtitleSelected: (subtitleId) async {
                selectedSubtitleId = subtitleId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-player-subtitle-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-menu-item-8')),
    );
    await tester.pumpAndSettle();

    expect(selectedSubtitleId, 8);
    expect(find.byKey(const Key('movie-player-subtitle-menu')), findsNothing);
  });

  testWidgets('移动字幕抽屉内联切换设置，返回后仍可选择字幕', (tester) async {
    final subtitleStateNotifier = ValueNotifier<MoviePlayerSubtitleState>(
      subtitleState(),
    );
    final applyingNotifier = ValueNotifier<bool>(false);
    addTearDown(subtitleStateNotifier.dispose);
    addTearDown(applyingNotifier.dispose);
    int? selectedSubtitleId;

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            return buildMoviePlayerMobileDrawerOverlay(
              context: context,
              activeDrawer: MoviePlayerMobileDrawerType.subtitle,
              subtitleState: subtitleStateNotifier.value,
              currentRate: 1,
              isApplyingSubtitleListenable: applyingNotifier,
              onDismiss: () {},
              onRateSelected: (_) async {},
              onSubtitleSelected: (subtitleId) async {
                selectedSubtitleId = subtitleId;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      AppSurfaceStyleScope.of(
        tester.element(
          find.byKey(
            const Key('movie-player-mobile-subtitle-drawer-settings'),
          ),
        ),
      ),
      AppSurfaceStyle.flat,
    );
    await tester.tap(
      find.byKey(const Key('movie-player-mobile-subtitle-drawer-settings')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-player-subtitle-settings')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-player-subtitle-settings-modal')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('movie-player-subtitle-settings-back')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-player-mobile-subtitle-drawer-item-7')),
    );
    await tester.pumpAndSettle();
    expect(selectedSubtitleId, 7);
  });
}
