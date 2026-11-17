#!/usr/bin/env bash
# 全量测试入口。
#
# 不要用裸 `flutter test`：它会把 test/ 下的文件逐个编译并序列化一次完整 dill，
# 每个文件都有无法通过并发消除的串行开销。这里先把当前测试动态聚合成少量 bundle
# 入口再并行运行；文件数和用例数变化时不需要更新本脚本。
#
#   ./scripts/test.sh                  # 全量
#   ./scripts/test.sh --name 'xxx'     # 额外参数透传给 flutter test
#
# 只改一个模块时不必走这里，直接跑那个文件更快：
#   flutter test test/features/movies/presentation/controllers/detail/movie_detail_controller_test.dart

set -euo pipefail

cd "$(dirname "$0")/.."

# ARB 生成物不入库，测试前显式生成，避免依赖 Flutter 的隐式生成时机。
flutter gen-l10n

# 每次重新生成（不到 1s）。bundle 不入库，所以不存在「加了 test 文件却忘了重新
# 生成、新测试被静默跳过」这种事。
dart run tool/gen_test_bundles.dart --quiet

# 每个 bundle 一个 worker。
concurrency="$(find test_bundles -name '*_test.dart' | wc -l | tr -d ' ')"

exec flutter test test_bundles -j "$concurrency" "$@"
