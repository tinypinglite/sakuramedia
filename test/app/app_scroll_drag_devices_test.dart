import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app.dart';

void main() {
  group('kAppScrollDragDevices', () {
    test('包含 unknown —— 无障碍/远程控制(RustDesk 等)注入手势依赖它才能滚动', () {
      // 回归守卫:历史上曾因 copyWith(dragDevices:) 整体替换默认集合时漏掉
      // PointerDeviceKind.unknown,导致 Android 上经 RustDesk 远程控制只能点击、
      // 无法滑动。删掉这一项会让该问题复发。
      expect(kAppScrollDragDevices, contains(PointerDeviceKind.unknown));
    });

    test('必须覆盖全部 PointerDeviceKind,避免覆盖默认集合时漏项', () {
      expect(kAppScrollDragDevices, equals(PointerDeviceKind.values.toSet()));
    });
  });
}
