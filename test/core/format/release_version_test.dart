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

  test('parses beta suffix and ranks the stable release above it', () {
    final beta = ReleaseVersion.tryParse('v0.10.0-beta.2');
    final stable = ReleaseVersion.tryParse('0.10.0');

    expect(beta, isNotNull);
    expect(beta!.toString(), '0.10.0-beta.2');
    expect(stable, isNotNull);
    expect(stable!.compareTo(beta), greaterThan(0));
    expect(beta.compareTo(stable), lessThan(0));
  });

  test('ranks betas by number and above the previous stable release', () {
    ReleaseVersion parse(String value) => ReleaseVersion.tryParse(value)!;

    expect(
      parse('0.10.0-beta.10').compareTo(parse('0.10.0-beta.9')),
      greaterThan(0),
    );
    expect(
      parse('0.10.0-beta.1').compareTo(parse('0.9.6')),
      greaterThan(0),
    );
  });

  test('returns null for prerelease suffixes outside the beta convention', () {
    expect(ReleaseVersion.tryParse('1.2.3-beta'), isNull);
    expect(ReleaseVersion.tryParse('1.2.3-rc.1'), isNull);
  });
}
