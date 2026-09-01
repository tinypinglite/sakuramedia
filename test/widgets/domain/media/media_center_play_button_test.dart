import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/media_center_play_button.dart';

void main() {
  testWidgets('centers the button and forwards taps', (tester) async {
    const stageKey = Key('media-center-play-stage');
    const buttonKey = Key('media-center-play-button');
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: stageKey,
              width: 300,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  MediaCenterPlayButton(
                    buttonKey: buttonKey,
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.byKey(buttonKey)),
      tester.getCenter(find.byKey(stageKey)),
    );

    await tester.tap(find.byKey(buttonKey));

    expect(tapped, isTrue);
  });
}
