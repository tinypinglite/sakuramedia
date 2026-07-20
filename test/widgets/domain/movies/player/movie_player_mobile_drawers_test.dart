import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';

void main() {
  group('Mobile drawer toggle buttons', () {
    testWidgets(
      'mobile speed button updates label from notifier without parent rebuild',
      (WidgetTester tester) async {
        final speedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
          const MoviePlayerMobileSpeedDisplayState(
            rate: 1.0,
            hasExplicitSelection: false,
          ),
        );
        addTearDown(speedDisplay.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: Row(
                children: buildMoviePlayerMobileDrawerToggleButtons(
                  activeDrawer: null,
                  speedDisplayListenable: speedDisplay,
                  onSpeedButtonPressed: () {},
                  onSubtitleButtonPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('倍速'), findsOneWidget);
        speedDisplay.value = const MoviePlayerMobileSpeedDisplayState(
          rate: 1.5,
          hasExplicitSelection: true,
        );
        await tester.pump();
        expect(find.text('1.5x'), findsOneWidget);
        expect(find.text('倍速'), findsNothing);
      },
    );

    testWidgets('mobile speed button keeps 1.0x after explicit selection', (
      WidgetTester tester,
    ) async {
      final speedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
        const MoviePlayerMobileSpeedDisplayState(
          rate: 1.0,
          hasExplicitSelection: true,
        ),
      );
      addTearDown(speedDisplay.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Row(
              children: buildMoviePlayerMobileDrawerToggleButtons(
                activeDrawer: null,
                speedDisplayListenable: speedDisplay,
                onSpeedButtonPressed: () {},
                onSubtitleButtonPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('倍速'), findsNothing);
    });
  });

  group('Mobile drawers', () {
    testWidgets('mobile drawer opens speed panel and toggles closed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
    });

    testWidgets('mobile drawer switches from speed to subtitle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-subtitle-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('movie-player-mobile-subtitle-drawer')),
        findsOneWidget,
      );
    });

    testWidgets('mobile drawer closes when tapping outside panel area', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerMobileDrawerHarness());

      await tester.tap(
        find.byKey(const Key('movie-player-mobile-speed-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
        findsNothing,
      );
    });

    testWidgets('mobile drawer is anchored to player area right edge', (
      WidgetTester tester,
    ) async {
      final applyingNotifier = ValueNotifier<bool>(false);
      addTearDown(applyingNotifier.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: const Key('movie-player-mobile-anchor-area'),
                width: 240,
                height: 420,
                child: Builder(
                  builder: (context) => Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.black),
                      buildMoviePlayerMobileDrawerOverlay(
                        context: context,
                        activeDrawer: MoviePlayerMobileDrawerType.speed,
                        subtitleState: MoviePlayerSubtitleState.empty,
                        currentRate: 1.0,
                        isApplyingSubtitleListenable: applyingNotifier,
                        onDismiss: () {},
                        onRateSelected: (_) async {},
                        onSubtitleSelected: (_) async {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final anchorRect = tester.getRect(
        find.byKey(const Key('movie-player-mobile-anchor-area')),
      );
      final drawerRect = tester.getRect(
        find.byKey(const Key('movie-player-mobile-speed-drawer')),
      );

      expect(drawerRect.right, lessThanOrEqualTo(anchorRect.right));
      expect(drawerRect.left, greaterThan(anchorRect.left));
      expect(drawerRect.top, equals(anchorRect.top));
      expect(drawerRect.bottom, equals(anchorRect.bottom));
    });

    testWidgets('info button toggles right-side info drawer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _MoviePlayerInfoDrawerHarness());

      expect(
        find.byKey(const Key('movie-player-info-side-drawer')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-info-side-drawer')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-player-info-side-drawer')),
        findsNothing,
      );
    });

    testWidgets(
      'info drawer closes on dismiss area tap and stays on inner tap',
      (WidgetTester tester) async {
        await tester.pumpWidget(const _MoviePlayerInfoDrawerHarness());

        await tester.tap(find.byKey(const Key('movie-player-info-button')));
        await tester.pumpAndSettle();

        final drawerFinder = find.byKey(
          const Key('movie-player-info-side-drawer'),
        );
        expect(drawerFinder, findsOneWidget);

        await tester.tap(drawerFinder);
        await tester.pumpAndSettle();
        expect(drawerFinder, findsOneWidget);

        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(drawerFinder, findsNothing);
      },
    );

    testWidgets(
      'mobile speed and subtitle drawers are mutually exclusive with info drawer',
      (WidgetTester tester) async {
        await tester.pumpWidget(const _MoviePlayerInfoDrawerHarness());

        await tester.tap(
          find.byKey(const Key('movie-player-mobile-speed-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('movie-player-mobile-speed-drawer')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('movie-player-info-side-drawer')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('movie-player-info-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('movie-player-mobile-speed-drawer')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('movie-player-info-side-drawer')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('movie-player-mobile-subtitle-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('movie-player-mobile-subtitle-drawer')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('movie-player-info-side-drawer')),
          findsNothing,
        );
      },
    );
  });
}

class _MoviePlayerMobileDrawerHarness extends StatefulWidget {
  const _MoviePlayerMobileDrawerHarness();

  @override
  State<_MoviePlayerMobileDrawerHarness> createState() =>
      _MoviePlayerMobileDrawerHarnessState();
}

class _MoviePlayerMobileDrawerHarnessState
    extends State<_MoviePlayerMobileDrawerHarness> {
  MoviePlayerMobileDrawerType? _activeDrawer;
  int? _selectedSubtitleId;
  final ValueNotifier<MoviePlayerMobileSpeedDisplayState>
      _speedDisplayNotifier = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
    const MoviePlayerMobileSpeedDisplayState(
      rate: 1.0,
      hasExplicitSelection: false,
    ),
  );
  final ValueNotifier<bool> _isApplyingSubtitleNotifier =
      ValueNotifier<bool>(false);

  final MoviePlayerSubtitleState _subtitleState =
      const MoviePlayerSubtitleState(
    options: <MoviePlayerSubtitleOption>[
      MoviePlayerSubtitleOption(
        subtitleId: 501,
        label: 'ABC-001.zh.srt',
        resolvedUrl: 'https://example.com/subtitles/501.srt',
      ),
    ],
    selectedSubtitleId: null,
    isLoading: false,
    fetchStatus: 'succeeded',
    errorMessage: null,
  );

  @override
  void dispose() {
    _speedDisplayNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleState = MoviePlayerSubtitleState(
      options: _subtitleState.options,
      selectedSubtitleId: _selectedSubtitleId,
      isLoading: false,
      fetchStatus: 'succeeded',
      errorMessage: null,
    );
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              buildMoviePlayerMobileDrawerOverlay(
                context: context,
                activeDrawer: _activeDrawer,
                subtitleState: subtitleState,
                currentRate: _speedDisplayNotifier.value.rate,
                isApplyingSubtitleListenable: _isApplyingSubtitleNotifier,
                onDismiss: () => setState(() => _activeDrawer = null),
                onRateSelected: (rate) async {
                  setState(() {
                    _activeDrawer = null;
                  });
                  _speedDisplayNotifier.value =
                      MoviePlayerMobileSpeedDisplayState(
                    rate: rate,
                    hasExplicitSelection: true,
                  );
                },
                onSubtitleSelected: (subtitleId) async {
                  setState(() {
                    _selectedSubtitleId = subtitleId;
                    _activeDrawer = null;
                  });
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 420,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buildMoviePlayerMobileDrawerToggleButtons(
                        activeDrawer: _activeDrawer,
                        speedDisplayListenable: _speedDisplayNotifier,
                        onSpeedButtonPressed: () => setState(() {
                          _activeDrawer =
                              _activeDrawer == MoviePlayerMobileDrawerType.speed
                                  ? null
                                  : MoviePlayerMobileDrawerType.speed;
                        }),
                        onSubtitleButtonPressed: () => setState(() {
                          _activeDrawer = _activeDrawer ==
                                  MoviePlayerMobileDrawerType.subtitle
                              ? null
                              : MoviePlayerMobileDrawerType.subtitle;
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoviePlayerInfoDrawerHarness extends StatefulWidget {
  const _MoviePlayerInfoDrawerHarness();

  @override
  State<_MoviePlayerInfoDrawerHarness> createState() =>
      _MoviePlayerInfoDrawerHarnessState();
}

class _MoviePlayerInfoDrawerHarnessState
    extends State<_MoviePlayerInfoDrawerHarness> {
  MoviePlayerMobileDrawerType? _activeDrawer;
  bool _isInfoDrawerOpen = false;
  int? _selectedSubtitleId;
  final ValueNotifier<MoviePlayerPlaybackInfoSnapshot> _infoNotifier =
      ValueNotifier<MoviePlayerPlaybackInfoSnapshot>(
    MoviePlayerPlaybackInfoSnapshot.empty,
  );
  final ValueNotifier<MoviePlayerMobileSpeedDisplayState>
      _speedDisplayNotifier = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
    const MoviePlayerMobileSpeedDisplayState(
      rate: 1.0,
      hasExplicitSelection: false,
    ),
  );
  final ValueNotifier<bool> _isApplyingSubtitleNotifier =
      ValueNotifier<bool>(false);

  final MoviePlayerSubtitleState _subtitleState =
      const MoviePlayerSubtitleState(
    options: <MoviePlayerSubtitleOption>[
      MoviePlayerSubtitleOption(
        subtitleId: 501,
        label: 'ABC-001.zh.srt',
        resolvedUrl: 'https://example.com/subtitles/501.srt',
      ),
    ],
    selectedSubtitleId: null,
    isLoading: false,
    fetchStatus: 'succeeded',
    errorMessage: null,
  );

  @override
  void dispose() {
    _infoNotifier.dispose();
    _speedDisplayNotifier.dispose();
    _isApplyingSubtitleNotifier.dispose();
    super.dispose();
  }

  void _toggleInfoDrawer() {
    setState(() {
      _activeDrawer = null;
      _isInfoDrawerOpen = !_isInfoDrawerOpen;
    });
  }

  void _toggleMobileDrawer(MoviePlayerMobileDrawerType drawerType) {
    setState(() {
      _isInfoDrawerOpen = false;
      _activeDrawer = _activeDrawer == drawerType ? null : drawerType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitleState = MoviePlayerSubtitleState(
      options: _subtitleState.options,
      selectedSubtitleId: _selectedSubtitleId,
      isLoading: false,
      fetchStatus: 'succeeded',
      errorMessage: null,
    );
    final topControls = buildMoviePlayerTopControls(
      movieNumber: 'ABP-123',
      onBackPressed: () {},
      onInfoPressed: _toggleInfoDrawer,
    );
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              buildMoviePlayerMobileDrawerOverlay(
                context: context,
                activeDrawer: _activeDrawer,
                subtitleState: subtitleState,
                currentRate: _speedDisplayNotifier.value.rate,
                isApplyingSubtitleListenable: _isApplyingSubtitleNotifier,
                onDismiss: () => setState(() => _activeDrawer = null),
                onRateSelected: (rate) async {
                  setState(() => _activeDrawer = null);
                  _speedDisplayNotifier.value =
                      MoviePlayerMobileSpeedDisplayState(
                    rate: rate,
                    hasExplicitSelection: true,
                  );
                },
                onSubtitleSelected: (subtitleId) async {
                  setState(() {
                    _selectedSubtitleId = subtitleId;
                    _activeDrawer = null;
                  });
                },
              ),
              buildMoviePlayerInfoSideDrawerOverlay(
                context: context,
                isOpen: _isInfoDrawerOpen,
                onDismiss: () => setState(() => _isInfoDrawerOpen = false),
                infoListenable: _infoNotifier,
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                  child: Row(children: topControls),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: 420,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buildMoviePlayerMobileDrawerToggleButtons(
                        activeDrawer: _activeDrawer,
                        speedDisplayListenable: _speedDisplayNotifier,
                        onSpeedButtonPressed: () => _toggleMobileDrawer(
                          MoviePlayerMobileDrawerType.speed,
                        ),
                        onSubtitleButtonPressed: () => _toggleMobileDrawer(
                          MoviePlayerMobileDrawerType.subtitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
