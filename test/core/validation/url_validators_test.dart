import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/validation/url_validators.dart';

void main() {
  group('url validators', () {
    test('validates http and https urls', () {
      expect(isValidHttpUrl('http://llm.internal:8000'), isTrue);
      expect(isValidHttpUrl('https://api.example.com/v1'), isTrue);
      expect(isValidHttpUrl('socks5://127.0.0.1:1080'), isFalse);
      expect(isValidHttpUrl('api.example.com'), isFalse);
    });
  });
}
