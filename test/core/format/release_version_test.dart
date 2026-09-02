import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/format/release_version.dart';

void main() {
  test('parses optional v prefix and compares three-part versions', () {
    final stable = ReleaseVersion.tryParse('1.2.3');
    final tagged = ReleaseVersion.tryParse('v1.2.4');

    expect(stable, isNotNull);
    expect(tagged, isNotNull);
    expect(tagged!.compareTo(stable!), greaterThan(0));
    expect(tagged.toString(), '1.2.4');
  });

  test('returns null for unsupported versions', () {
    expect(ReleaseVersion.tryParse('nightly'), isNull);
    expect(ReleaseVersion.tryParse('1.2'), isNull);
  });
}
