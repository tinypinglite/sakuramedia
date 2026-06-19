import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/media_import/data/failure_reason_descriptions.dart';

void main() {
  group('describeFailureReason', () {
    test('返回已登记 reason 的中文文案', () {
      expect(
        describeFailureReason('already_indexed_path'),
        '已在库中：该文件路径已登记，跳过重复导入',
      );
      expect(
        describeFailureReason('duplicate_fingerprint'),
        '内容重复：库中已存在相同内容的文件，跳过导入',
      );
      expect(
        describeFailureReason('movie_number_not_found'),
        '未识别番号：无法从文件名/路径解析出影片番号',
      );
    });

    test('未知 reason 回落原值', () {
      expect(describeFailureReason('some_new_reason'), 'some_new_reason');
    });

    test('空 reason 落「未知原因」', () {
      expect(describeFailureReason(''), '未知原因');
    });
  });
}
