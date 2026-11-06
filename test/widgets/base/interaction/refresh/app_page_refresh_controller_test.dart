import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_controller.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPageRefreshController', () {
    test('tracks the most recently registered callback', () {
      final controller = AppPageRefreshController();
      addTearDown(controller.dispose);

      Future<void> first() async {}
      Future<void> second() async {}

      expect(controller.current, isNull);

      controller.registrar.register(first);
      expect(controller.current, same(first));

      controller.registrar.register(second);
      expect(controller.current, same(second));

      controller.registrar.unregister(second);
      expect(controller.current, same(first));

      controller.registrar.unregister(first);
      expect(controller.current, isNull);
    });

    test('re-registering the same callback does not duplicate it', () {
      final controller = AppPageRefreshController();
      addTearDown(controller.dispose);

      Future<void> callback() async {}

      controller.registrar.register(callback);
      controller.registrar.register(callback);
      expect(controller.current, same(callback));

      controller.registrar.unregister(callback);
      expect(controller.current, isNull);
    });

    test('notifies listeners only when the active callback changes', () {
      final controller = AppPageRefreshController();
      addTearDown(controller.dispose);

      Future<void> first() async {}
      Future<void> second() async {}
      final seen = <AppPageRefreshCallback?>[];
      controller.listenable.addListener(() => seen.add(controller.current));

      controller.registrar.register(first);
      controller.registrar.register(second);
      controller.registrar.unregister(second);
      controller.registrar.unregister(first);

      expect(seen, <AppPageRefreshCallback?>[first, second, first, null]);
    });
  });
}
