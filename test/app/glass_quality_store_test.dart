import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/glass_quality_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesGlassQualityStore', () {
    test('reads null when no value is stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPreferencesGlassQualityStore(
        await SharedPreferences.getInstance(),
      );

      expect(store.read(), isNull);
    });

    test('saves and reads the settled quality by name', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = SharedPreferencesGlassQualityStore(
        await SharedPreferences.getInstance(),
      );

      await store.save(GlassQuality.minimal);

      final reloaded = SharedPreferencesGlassQualityStore(
        await SharedPreferences.getInstance(),
      );
      expect(reloaded.read(), GlassQuality.minimal);
    });

    test('falls back to null for an unknown quality name', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesGlassQualityStore.qualityKey: 'ultra',
      });
      final store = SharedPreferencesGlassQualityStore(
        await SharedPreferences.getInstance(),
      );

      expect(store.read(), isNull);
    });
  });

  group('InMemoryGlassQualityStore', () {
    test('defaults to null and stores quality in memory', () async {
      final store = InMemoryGlassQualityStore();
      expect(store.read(), isNull);

      await store.save(GlassQuality.premium);
      expect(store.read(), GlassQuality.premium);
    });
  });
}
