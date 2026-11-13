import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/media/video/player_viewport.dart';

void main() {
  test('竖屏判定只看播放区实际约束', () {
    expect(
      isPortraitPlayerViewport(
        const BoxConstraints(maxWidth: 430, maxHeight: 932),
      ),
      isTrue,
    );
    expect(
      isPortraitPlayerViewport(
        const BoxConstraints(maxWidth: 932, maxHeight: 430),
      ),
      isFalse,
    );
  });

  test('窄播放区即使判定为横屏也使用紧凑控制条', () {
    expect(
      shouldUseCompactPlayerControls(
        constraints: const BoxConstraints(maxWidth: 232, maxHeight: 740),
      ),
      isTrue,
    );
    expect(
      shouldUseCompactPlayerControls(
        constraints: const BoxConstraints(maxWidth: 844, maxHeight: 390),
      ),
      isFalse,
    );
  });
}
