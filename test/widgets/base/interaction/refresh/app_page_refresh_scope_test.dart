import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

void main() {
  group('AppPageRefreshScope', () {
    testWidgets('registers callback with nearest registrar on mount', (
      tester,
    ) async {
      final registered = <AppPageRefreshCallback>[];
      final unregistered = <AppPageRefreshCallback>[];
      final registrar = AppPageRefreshRegistrar(
        register: registered.add,
        unregister: unregistered.add,
      );

      Future<void> onRefresh() async {}

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPageRefreshRegistrarScope(
            registrar: registrar,
            child: AppPageRefreshScope(
              onRefresh: onRefresh,
              child: const SizedBox(),
            ),
          ),
        ),
      );

      expect(registered, hasLength(1));
      expect(unregistered, isEmpty);
    });

    testWidgets('unregisters on dispose', (tester) async {
      final registered = <AppPageRefreshCallback>[];
      final unregistered = <AppPageRefreshCallback>[];
      final registrar = AppPageRefreshRegistrar(
        register: registered.add,
        unregister: unregistered.add,
      );

      Future<void> onRefresh() async {}

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPageRefreshRegistrarScope(
            registrar: registrar,
            child: AppPageRefreshScope(
              onRefresh: onRefresh,
              child: const SizedBox(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPageRefreshRegistrarScope(
            registrar: registrar,
            child: const SizedBox(),
          ),
        ),
      );

      expect(unregistered, hasLength(1));
      expect(identical(registered.single, unregistered.single), isTrue);
    });

    testWidgets(
      'registered callback always invokes latest onRefresh across rebuilds',
      (tester) async {
        AppPageRefreshCallback? captured;
        final registrar = AppPageRefreshRegistrar(
          register: (cb) => captured = cb,
          unregister: (_) {},
        );

        var callCount = 0;
        Future<void> first() async {
          callCount = 1;
        }

        Future<void> second() async {
          callCount = 2;
        }

        Widget buildTree(AppPageRefreshCallback cb) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: AppPageRefreshRegistrarScope(
              registrar: registrar,
              child: AppPageRefreshScope(
                onRefresh: cb,
                child: const SizedBox(),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree(first));
        await captured?.call();
        expect(callCount, 1);

        await tester.pumpWidget(buildTree(second));
        await captured?.call();
        expect(callCount, 2);
      },
    );

    testWidgets('no-op when no registrar in tree', (tester) async {
      Future<void> onRefresh() async {}

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPageRefreshScope(
            onRefresh: onRefresh,
            child: const SizedBox(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
