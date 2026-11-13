import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_controls_theme.dart';
import 'package:sakuramedia/widgets/domain/media/collapsible_player_split_view.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_controls.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('360 宽竖屏长番号顶栏不溢出且信息按钮与面板开关不重叠', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 1), Area(flex: 0)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(360, 740),
      home: Builder(
        builder: (context) {
          final trailingInset = resolveMoviePlayerTopBarTrailingInset(
            Theme.of(context),
            reserveTopRightToggle: true,
          );
          return CollapsiblePlayerSplitView(
            controller: controller,
            collapsible: true,
            panelAvailable: true,
            handleKey: const Key('panel-handle'),
            leftBuilder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                Positioned(
                  top: context.appOverlayTokens.playerControlBarTopInset,
                  left:
                      context.appOverlayTokens.playerControlBarHorizontalInset,
                  right: trailingInset,
                  height: 56,
                  child: Row(
                    children: buildMoviePlayerTopControls(
                      movieNumber: 'EBWH-356 中文字幕特别加长标题',
                      onBackPressed: () {},
                      onInfoPressed: () {},
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
            rightBuilder: (context) => const SizedBox.expand(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final infoRect = tester.getRect(
      find.byKey(const Key('movie-player-info-button')),
    );
    final panelRect = tester.getRect(find.byKey(const Key('panel-handle')));

    expect(infoRect.overlaps(panelRect), isFalse);
  });

  testWidgets('布局过渡帧 356 宽紧凑顶栏长番号不溢出', (tester) async {
    final controller = MultiSplitViewController(
      areas: <Area>[Area(flex: 1), Area(flex: 0)],
    );
    addTearDown(controller.dispose);

    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(356, 360),
      home: Builder(
        builder: (context) {
          final trailingInset = resolveMoviePlayerTopBarTrailingInset(
            Theme.of(context),
            reserveTopRightToggle: true,
          );
          return CollapsiblePlayerSplitView(
            controller: controller,
            collapsible: true,
            panelAvailable: true,
            handleKey: const Key('panel-handle'),
            leftBuilder: (context) => Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                Positioned(
                  top: context.appOverlayTokens.playerControlBarTopInset,
                  left:
                      context.appOverlayTokens.playerControlBarHorizontalInset,
                  right: trailingInset,
                  height: 56,
                  child: Row(
                    children: buildMoviePlayerTopControls(
                      movieNumber: 'EBWH-356 中文字幕特别加长标题',
                      onBackPressed: () {},
                      onInfoPressed: () {},
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
            rightBuilder: (context) => const SizedBox.expand(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('176 宽极端约束下顶栏仍可压缩', (tester) async {
    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 176,
            height: 56,
            child: _TopControlsRow(movieNumber: 'EBWH-356 中文字幕特别加长标题'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('外部尾部按钮与返回番号共用同一压缩行', (tester) async {
    await pumpWithProviders(
      tester,
      theme: buildSakuraMobileThemeData(),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 176,
            height: 56,
            child: _TopControlsRow(
              movieNumber: 'EBWH-356 中文字幕特别加长标题',
              withTrailing: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _TopControlsRow extends StatelessWidget {
  const _TopControlsRow({required this.movieNumber, this.withTrailing = false});

  final String movieNumber;
  final bool withTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: buildMoviePlayerTopControls(
        movieNumber: movieNumber,
        onBackPressed: () {},
        compact: true,
        onInfoPressed: withTrailing ? null : () {},
        trailingControls: withTrailing
            ? const <Widget>[
                SizedBox(width: 44, height: 44),
                SizedBox(width: 44, height: 44),
              ]
            : const <Widget>[],
      ),
    );
  }
}
