import 'package:flutter/widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/app/network_proxy_store.dart';
import 'package:sakuramedia/app/onboarding_store.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';
import 'package:sakuramedia/core/platform/tv_device.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_state_store.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

export 'package:sakuramedia/app/app.dart';

Future<void> main() async {
  await bootstrapApplication();
  final platformOverride = await detectAppPlatformOverride();
  final sessionStore = await SessionStore.create();
  final networkProxyStore = await SharedPreferencesNetworkProxyStore.create();
  installNetworkProxyOverrides(networkProxyStore.read());
  final appearanceStore = await SharedPreferencesAppearanceStore.create();
  final languageStore = await SharedPreferencesLanguageStore.create();
  final onboardingStore = await SharedPreferencesOnboardingStore.create();
  final announcementStateStore =
      await SharedPreferencesAnnouncementStateStore.create();
  await AppSurfaceRuntime.ensureInitialized(
    style: appearanceStore.read().surfaceStyle,
  );
  runApp(
    MyApp(
      platformOverride: platformOverride,
      sessionStore: sessionStore,
      appearanceStore: appearanceStore,
      languageStore: languageStore,
      networkProxyStore: networkProxyStore,
      onboardingStore: onboardingStore,
      announcementStateStore: announcementStateStore,
    ),
  );
}
