import 'package:flutter/widgets.dart';
import 'package:sakuramedia/app/app_page_state_cache.dart';

class CachedPageStateHandle<T extends AppPageStateEntry> {
  const CachedPageStateHandle._({required this.value, required this.ownsState});

  final T value;
  final bool ownsState;

  void dispose() {
    if (ownsState) {
      value.dispose();
    }
  }
}

CachedPageStateHandle<T> obtainCachedPageState<T extends AppPageStateEntry>(
  BuildContext context, {
  required String key,
  required T Function() create,
}) {
  final cache = maybeReadAppPageStateCache(context);
  if (cache == null) {
    return CachedPageStateHandle<T>._(value: create(), ownsState: true);
  }
  return CachedPageStateHandle<T>._(
    value: cache.obtain<T>(key: key, create: create),
    ownsState: false,
  );
}
