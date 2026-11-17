import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

void main() {
  group('AppStatusChipPalette.forSemantic', () {
    test('语义映射到共享 tone', () {
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.neutral).tone,
        AppPillTone.neutral,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.inProgress).tone,
        AppPillTone.info,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.queued).tone,
        AppPillTone.neutral,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.success).tone,
        AppPillTone.success,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.warning).tone,
        AppPillTone.warning,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.error).tone,
        AppPillTone.error,
      );
      expect(
        AppStatusChipPalette.forSemantic(AppStatusSemantic.muted).tone,
        AppPillTone.muted,
      );
    });

    test('icon 可覆盖默认图标', () {
      const icon = Icons.hourglass_top;
      final palette = AppStatusChipPalette.forSemantic(
        AppStatusSemantic.queued,
        icon: icon,
      );

      expect(palette.icon, icon);
      expect(palette.tone, AppPillTone.neutral);
    });

    test('info 命名构造使用 info tone', () {
      expect(AppStatusChipPalette.info().tone, AppPillTone.info);
    });
  });

  group('AppStatusSemantic.fromWire', () {
    test('常见状态字符串归一', () {
      expect(
        AppStatusSemantic.fromWire('  In-Progress '),
        AppStatusSemantic.inProgress,
      );
      expect(AppStatusSemantic.fromWire('pending'), AppStatusSemantic.queued);
      expect(AppStatusSemantic.fromWire('partial'), AppStatusSemantic.warning);
      expect(AppStatusSemantic.fromWire('failed'), AppStatusSemantic.error);
      expect(AppStatusSemantic.fromWire('blocked'), AppStatusSemantic.muted);
    });

    test('未知/空值回落到 neutral', () {
      expect(AppStatusSemantic.fromWire(null), AppStatusSemantic.neutral);
      expect(
        AppStatusSemantic.fromWire('future_status'),
        AppStatusSemantic.neutral,
      );
    });
  });
}
