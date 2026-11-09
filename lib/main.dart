import 'package:flutter/widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/app/onboarding_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

export 'package:sakuramedia/app/app.dart';

Future<void> main() async {
  await bootstrapApplication();
  final sessionStore = await SessionStore.create();
  final appearanceStore = await SharedPreferencesAppearanceStore.create();
  final languageStore = await SharedPreferencesLanguageStore.create();
  final onboardingStore = await SharedPreferencesOnboardingStore.create();
  await AppSurfaceRuntime.ensureInitialized(
    style: appearanceStore.read().surfaceStyle,
  );
  runApp(
    MyApp(
      sessionStore: sessionStore,
      appearanceStore: appearanceStore,
      languageStore: languageStore,
      onboardingStore: onboardingStore,
    ),
  );
}
