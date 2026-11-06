import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  test('默认动效节奏固定', () {
    const motion = AppMotion.defaults();

    expect(motion.fast, const Duration(milliseconds: 120));
    expect(motion.normal, const Duration(milliseconds: 180));
    expect(motion.slow, const Duration(milliseconds: 250));
    expect(motion.slower, const Duration(milliseconds: 320));
    expect(motion.standard, Curves.easeOutCubic);
  });

  test('copyWith 与 lerp 保持 Duration 插值', () {
    const motion = AppMotion.defaults();
    final slower = motion.copyWith(fast: const Duration(milliseconds: 220));

    expect(slower.fast, const Duration(milliseconds: 220));
    expect(motion.lerp(slower, 0.5).fast, const Duration(milliseconds: 170));
  });

  test('主题默认接入 AppMotion', () {
    final theme = buildSakuraMobileThemeData();

    expect(theme.appMotion.normal, const Duration(milliseconds: 180));
    expect(theme.appMotion.standard, Curves.easeOutCubic);
  });
}
