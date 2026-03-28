import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_feature_actions.dart';

void main() {
  group('extractCollectionFeaturePrefix', () {
    test('keeps full prefix before trailing digits', () {
      expect(extractCollectionFeaturePrefix('OFJE-888'), 'OFJE-');
      expect(extractCollectionFeaturePrefix('FC2-PPV-1234567'), 'FC2-PPV-');
      expect(extractCollectionFeaturePrefix('ABP123'), 'ABP');
      expect(extractCollectionFeaturePrefix('T28-630'), 'T28-');
    });

    test('normalizes case and trims whitespace', () {
      expect(extractCollectionFeaturePrefix('  ofje-888  '), 'OFJE-');
    });

    test('returns null when trailing numeric segment is missing', () {
      expect(extractCollectionFeaturePrefix('FC2-PPV'), isNull);
      expect(extractCollectionFeaturePrefix(''), isNull);
      expect(extractCollectionFeaturePrefix('1234'), isNull);
    });
  });
}
