import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_resume_policy.dart';

void main() {
  test('returns stored position when it is useful for resume', () {
    expect(
      resolvePlaybackResumePosition(
        storedPositionSeconds: 754,
        durationSeconds: 3600,
      ),
      const Duration(seconds: 754),
    );
  });

  test('ignores records near the beginning', () {
    expect(
      resolvePlaybackResumePosition(
        storedPositionSeconds: 10,
        durationSeconds: 3600,
      ),
      isNull,
    );
  });

  test('ignores records near or beyond the end', () {
    expect(
      resolvePlaybackResumePosition(
        storedPositionSeconds: 3580,
        durationSeconds: 3600,
      ),
      isNull,
    );
    expect(
      resolvePlaybackResumePosition(
        storedPositionSeconds: 3700,
        durationSeconds: 3600,
      ),
      isNull,
    );
  });
}
