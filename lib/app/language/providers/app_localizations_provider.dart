import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/network/api_error_message.dart' as api_error;
import 'package:sakuramedia/l10n/app_localizations.dart';

part 'app_localizations_provider.g.dart';

/// 当前语言对应的 [AppLocalizations]。
///
/// widget 仍优先用 `AppLocalizations.of(context)`；provider/data 层没有
/// BuildContext，通过这个 provider 取同一份当前语言文案。
@Riverpod(keepAlive: true)
AppLocalizations appLocalizations(Ref ref) {
  final language = ref.watch(appLanguageControllerProvider);
  return lookupAppLocalizations(language.locale);
}

/// provider 层没有 BuildContext，用这个扩展把当前语言传给错误文案。
extension ApiErrorMessageRefX on Ref {
  String apiErrorMessage(Object error, {required String fallback}) {
    return api_error.apiErrorMessage(
      error,
      fallback: fallback,
      l10n: read(appLocalizationsProvider),
    );
  }
}
