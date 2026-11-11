import 'package:shared_preferences/shared_preferences.dart';

abstract class AnnouncementStateStore {
  DateTime? get lastSeenAt;

  Set<String> get acknowledgedIds;

  Future<void> markSeen(DateTime publishedAt);

  Future<void> acknowledge(Iterable<String> ids);
}

class SharedPreferencesAnnouncementStateStore
    implements AnnouncementStateStore {
  SharedPreferencesAnnouncementStateStore(this._preferences);

  static const String lastSeenAtKey = 'announcements.last_seen_at';
  static const String acknowledgedIdsKey = 'announcements.acknowledged_ids';

  final SharedPreferences _preferences;

  static Future<AnnouncementStateStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAnnouncementStateStore(preferences);
  }

  @override
  DateTime? get lastSeenAt {
    final rawValue = _preferences.getString(lastSeenAtKey);
    return rawValue == null ? null : DateTime.tryParse(rawValue);
  }

  @override
  Set<String> get acknowledgedIds =>
      (_preferences.getStringList(acknowledgedIdsKey) ?? const <String>[])
          .toSet();

  @override
  Future<void> markSeen(DateTime publishedAt) async {
    final previous = lastSeenAt;
    if (previous != null && !publishedAt.isAfter(previous)) {
      return;
    }
    try {
      await _preferences.setString(
        lastSeenAtKey,
        publishedAt.toUtc().toIso8601String(),
      );
    } catch (_) {
      // 本地记录失败不阻塞 UI；最坏情况下下次再提示一次。
    }
  }

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    final merged = <String>{...acknowledgedIds, ...ids};
    try {
      await _preferences.setStringList(
        acknowledgedIdsKey,
        merged.toList(growable: false),
      );
    } catch (_) {
      // 确认失败时仍允许关闭弹窗，避免用户被无法关闭的界面卡住。
    }
  }
}

class InMemoryAnnouncementStateStore implements AnnouncementStateStore {
  InMemoryAnnouncementStateStore({
    DateTime? lastSeenAt,
    Iterable<String> acknowledgedIds = const <String>[],
  }) : _lastSeenAt = lastSeenAt,
       _acknowledgedIds = acknowledgedIds.toSet();

  DateTime? _lastSeenAt;
  final Set<String> _acknowledgedIds;

  @override
  DateTime? get lastSeenAt => _lastSeenAt;

  @override
  Set<String> get acknowledgedIds => Set<String>.unmodifiable(_acknowledgedIds);

  @override
  Future<void> markSeen(DateTime publishedAt) async {
    final previous = _lastSeenAt;
    if (previous == null || publishedAt.isAfter(previous)) {
      _lastSeenAt = publishedAt;
    }
  }

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    _acknowledgedIds.addAll(ids);
  }
}
