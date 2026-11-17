import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';

void main() {
  test('back guard runs registrations in order and stops on refusal', () async {
    final controller = AppBackGuardController();
    final calls = <String>[];
    var allowSecond = false;

    controller.register(() async {
      calls.add('first');
      return true;
    });
    controller.register(() async {
      calls.add('second');
      return allowSecond;
    });
    controller.register(() async {
      calls.add('third');
      return true;
    });

    expect(await controller.canLeave(), isFalse);
    expect(calls, <String>['first', 'second']);

    calls.clear();
    allowSecond = true;
    expect(await controller.canLeave(), isTrue);
    expect(calls, <String>['first', 'second', 'third']);
  });

  test('disposed registration no longer participates', () async {
    final controller = AppBackGuardController();
    var calls = 0;
    final registration = controller.register(() async {
      calls++;
      return false;
    });

    registration.dispose();

    expect(await controller.canLeave(), isTrue);
    expect(calls, 0);
  });
}
