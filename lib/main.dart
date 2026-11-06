import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/app/glass_quality_store.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';

export 'package:sakuramedia/app/app.dart';

Future<void> main() async {
  await bootstrapApplication();
  await LiquidGlassWidgets.initialize();
  final sessionStore = await SessionStore.create();
  final appearanceStore = await SharedPreferencesAppearanceStore.create();
  final languageStore = await SharedPreferencesLanguageStore.create();
  final glassQualityStore = await SharedPreferencesGlassQualityStore.create();
  runApp(
    MyApp(
      sessionStore: sessionStore,
      appearanceStore: appearanceStore,
      languageStore: languageStore,
      glassQualityStore: glassQualityStore,
    ),
  );
}
