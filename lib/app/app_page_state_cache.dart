import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';

abstract interface class AppPageStateEntry {
  void dispose();
}

class AppPageStateCache extends ChangeNotifier {
  AppPageStateCache({this.maxEntries = 24});

  final int maxEntries;
  final LinkedHashMap<String, AppPageStateEntry> _entries =
      LinkedHashMap<String, AppPageStateEntry>();
  SessionStore? _boundSessionStore;
  bool _lastHasSession = false;

  int get size => _entries.length;

  T obtain<T extends AppPageStateEntry>({
    required String key,
    required T Function() create,
  }) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing;
      return existing as T;
    }

    final created = create();
    _entries[key] = created;
    _evictIfNeeded();
    return created;
  }

  void remove(String key) {
    final removed = _entries.remove(key);
    if (removed == null) {
      return;
    }
    removed.dispose();
  }

  void clear() {
    if (_entries.isEmpty) {
      return;
    }
    final values = _entries.values.toList(growable: false);
    _entries.clear();
    for (final value in values) {
      value.dispose();
    }
  }

  void bindSessionStore(SessionStore sessionStore) {
    if (identical(_boundSessionStore, sessionStore)) {
      return;
    }
    _boundSessionStore?.removeListener(_handleSessionChanged);
    _boundSessionStore = sessionStore;
    _lastHasSession = sessionStore.hasSession;
    _boundSessionStore?.addListener(_handleSessionChanged);
    if (!_lastHasSession) {
      clear();
    }
  }

  void _handleSessionChanged() {
    final sessionStore = _boundSessionStore;
    if (sessionStore == null) {
      return;
    }
    final hasSession = sessionStore.hasSession;
    if (!hasSession && _lastHasSession) {
      clear();
    }
    _lastHasSession = hasSession;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      final oldestKey = _entries.keys.first;
      final removed = _entries.remove(oldestKey);
      removed?.dispose();
    }
  }

  @override
  void dispose() {
    _boundSessionStore?.removeListener(_handleSessionChanged);
    clear();
    super.dispose();
  }
}

AppPageStateCache? maybeReadAppPageStateCache(BuildContext context) {
  try {
    return context.read<AppPageStateCache>();
  } on ProviderNotFoundException {
    return null;
  }
}
