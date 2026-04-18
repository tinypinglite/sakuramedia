import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedLoadController', () {
    test('initialize loads the first page and exposes state', () async {
      final controller = PagedLoadController<int>(
        fetchPage: (page, pageSize) async {
          expect(page, 1);
          expect(pageSize, 2);
          return const PaginatedResponseDto<int>(
            items: <int>[1, 2],
            page: 1,
            pageSize: 2,
            total: 3,
          );
        },
        pageSize: 2,
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );

      await controller.initialize();

      expect(controller.items, <int>[1, 2]);
      expect(controller.currentPage, 1);
      expect(controller.total, 3);
      expect(controller.hasLoadedOnce, isTrue);
      expect(controller.hasMore, isTrue);
      expect(controller.initialErrorMessage, isNull);
      expect(controller.loadMoreErrorMessage, isNull);

      controller.dispose();
    });

    test('initialize is idempotent', () async {
      var callCount = 0;
      final controller = PagedLoadController<int>(
        fetchPage: (page, pageSize) async {
          callCount += 1;
          return const PaginatedResponseDto<int>(
            items: <int>[1],
            page: 1,
            pageSize: 24,
            total: 1,
          );
        },
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );

      await controller.initialize();
      await controller.initialize();

      expect(callCount, 1);

      controller.dispose();
    });

    test('initial load failure stores error message', () async {
      final controller = PagedLoadController<int>(
        fetchPage:
            (_, __) =>
                Future<PaginatedResponseDto<int>>.error(Exception('boom')),
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );

      await controller.initialize();

      expect(controller.items, isEmpty);
      expect(controller.hasLoadedOnce, isFalse);
      expect(controller.initialErrorMessage, 'initial failed');
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('loadMore appends items until total is exhausted', () async {
      final controller = PagedLoadController<int>(
        fetchPage: (page, pageSize) async {
          if (page == 1) {
            return const PaginatedResponseDto<int>(
              items: <int>[1, 2],
              page: 1,
              pageSize: 2,
              total: 3,
            );
          }
          return const PaginatedResponseDto<int>(
            items: <int>[3],
            page: 2,
            pageSize: 2,
            total: 3,
          );
        },
        pageSize: 2,
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );

      await controller.initialize();
      await controller.loadMore();
      await controller.loadMore();

      expect(controller.items, <int>[1, 2, 3]);
      expect(controller.currentPage, 2);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('loadMore failure keeps existing items and surfaces error', () async {
      final controller = PagedLoadController<int>(
        fetchPage: (page, pageSize) async {
          if (page == 1) {
            return const PaginatedResponseDto<int>(
              items: <int>[1, 2],
              page: 1,
              pageSize: 2,
              total: 4,
            );
          }
          throw Exception('later page failed');
        },
        pageSize: 2,
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );

      await controller.initialize();
      await controller.loadMore();

      expect(controller.items, <int>[1, 2]);
      expect(controller.currentPage, 1);
      expect(controller.loadMoreErrorMessage, 'load more failed');
      expect(controller.hasMore, isTrue);

      controller.dispose();
    });

    testWidgets('scroll listener triggers loadMore near list bottom', (
      WidgetTester tester,
    ) async {
      final requestedPages = <int>[];
      final controller = PagedLoadController<int>(
        fetchPage: (page, pageSize) async {
          requestedPages.add(page);
          if (page == 1) {
            return const PaginatedResponseDto<int>(
              items: <int>[1, 2],
              page: 1,
              pageSize: 2,
              total: 3,
            );
          }
          return const PaginatedResponseDto<int>(
            items: <int>[3],
            page: 2,
            pageSize: 2,
            total: 3,
          );
        },
        pageSize: 2,
        loadMoreTriggerOffset: 50,
        initialLoadErrorText: 'initial failed',
        loadMoreErrorText: 'load more failed',
      );
      controller.attachScrollListener();
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller.scrollController,
            itemCount: 60,
            itemBuilder:
                (_, index) => SizedBox(height: 50, child: Text('row-$index')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(requestedPages, <int>[1, 2]);
      expect(controller.items, <int>[1, 2, 3]);

      controller.dispose();
    });

    test(
      'dispose prevents late async completion from notifying again',
      () async {
        final completer = Completer<PaginatedResponseDto<int>>();
        final controller = PagedLoadController<int>(
          fetchPage: (_, __) => completer.future,
          initialLoadErrorText: 'initial failed',
          loadMoreErrorText: 'load more failed',
        );
        var notifyCount = 0;
        controller.addListener(() {
          notifyCount += 1;
        });

        final initializeFuture = controller.initialize();
        expect(notifyCount, 1);

        controller.dispose();
        completer.complete(
          const PaginatedResponseDto<int>(
            items: <int>[1],
            page: 1,
            pageSize: 24,
            total: 1,
          ),
        );
        await initializeFuture;

        expect(notifyCount, 1);
      },
    );
  });
}
