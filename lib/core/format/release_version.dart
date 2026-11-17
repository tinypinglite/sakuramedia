/// GitHub Release tag 使用的版本号，beta 版本带 `-beta.N` 预发布段。
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch, {this.beta});

  final int major;
  final int minor;
  final int patch;

  /// beta 序号；正式版为 null。
  final int? beta;

  static ReleaseVersion? tryParse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final beta = match.group(4);
    return ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      beta: beta == null ? null : int.parse(beta),
    );
  }

  @override
  int compareTo(ReleaseVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }
    final patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) {
      return patchComparison;
    }
    if (beta == other.beta) {
      return 0;
    }
    // 同号的正式版高于 beta；beta 之间按序号比较。
    if (beta == null) {
      return 1;
    }
    if (other.beta == null) {
      return -1;
    }
    return beta!.compareTo(other.beta!);
  }

  @override
  String toString() =>
      beta == null ? '$major.$minor.$patch' : '$major.$minor.$patch-beta.$beta';
}
