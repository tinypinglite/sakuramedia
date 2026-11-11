import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_state_store_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcements_api_provider.dart';

part 'announcement_feed_provider.g.dart';

@immutable
class AnnouncementFeedState {
  const AnnouncementFeedState({
    this.active = const <AnnouncementDto>[],
    this.criticalUnacknowledged = const <AnnouncementDto>[],
    this.hasUnseen = false,
    this.unseenCount = 0,
  });

  static const AnnouncementFeedState initial = AnnouncementFeedState();

  final List<AnnouncementDto> active;
  final List<AnnouncementDto> criticalUnacknowledged;
  final bool hasUnseen;
  final int unseenCount;

  AnnouncementFeedState copyWith({
    List<AnnouncementDto>? active,
    List<AnnouncementDto>? criticalUnacknowledged,
    bool? hasUnseen,
    int? unseenCount,
  }) {
    return AnnouncementFeedState(
      active: active ?? this.active,
      criticalUnacknowledged:
          criticalUnacknowledged ?? this.criticalUnacknowledged,
      hasUnseen: hasUnseen ?? this.hasUnseen,
      unseenCount: unseenCount ?? this.unseenCount,
    );
  }
}

@Riverpod(keepAlive: true)
class AnnouncementFeed extends _$AnnouncementFeed {
  Future<void>? _loadFuture;

  @override
  AnnouncementFeedState build() {
    scheduleMicrotask(load);
    return AnnouncementFeedState.initial;
  }

  Future<void> load() {
    final inFlight = _loadFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final next = _load();
    _loadFuture = next;
    return next.whenComplete(() {
      if (identical(_loadFuture, next)) {
        _loadFuture = null;
      }
    });
  }

  Future<void> _load() async {
    try {
      final session = ref.read(sessionStoreProvider);
      if (!session.hasSession) {
        state = AnnouncementFeedState.initial;
        return;
      }

      await ref.read(appVersionInfoProvider.notifier).load();
      if (!ref.mounted) {
        return;
      }
      final versionInfo =
          ref.read(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
      final items = await ref.read(announcementsApiProvider).getAnnouncements();
      if (!ref.mounted) {
        return;
      }
      if (!ref.read(sessionStoreProvider).hasSession) {
        state = AnnouncementFeedState.initial;
        return;
      }
      _apply(
        items: items,
        frontendVersion: versionInfo.frontendVersion,
        backendVersion: versionInfo.backendVersion,
      );
    } catch (_) {
      // 公告是尽力而为的通知，网络/解析失败不阻塞主流程。
    }
  }

  void _apply({
    required List<AnnouncementDto> items,
    required String frontendVersion,
    required String backendVersion,
  }) {
    final now = DateTime.now();
    final active =
        items
            .where(
              (item) =>
                  item.isActiveAt(now) &&
                  item.targetsVersions(
                    frontendVersion: frontendVersion,
                    backendVersion: backendVersion,
                  ),
            )
            .toList(growable: false)
          ..sort(_compareAnnouncements);

    final store = ref.read(announcementStateStoreProvider);
    final acknowledgedIds = store.acknowledgedIds;
    final criticalUnacknowledged = active
        .where(
          (item) =>
              item.level == AnnouncementLevel.critical &&
              !acknowledgedIds.contains(item.id),
        )
        .toList(growable: false);
    final lastSeenAt = store.lastSeenAt;
    final unseenCount = active
        .where(
          (item) =>
              item.level != AnnouncementLevel.critical &&
              (lastSeenAt == null || item.publishedAt.isAfter(lastSeenAt)),
        )
        .length;

    state = AnnouncementFeedState(
      active: List<AnnouncementDto>.unmodifiable(active),
      criticalUnacknowledged: List<AnnouncementDto>.unmodifiable(
        criticalUnacknowledged,
      ),
      hasUnseen: unseenCount > 0,
      unseenCount: unseenCount,
    );
  }

  Future<void> markSeen() async {
    DateTime? latest;
    for (final item in state.active) {
      if (latest == null || item.publishedAt.isAfter(latest)) {
        latest = item.publishedAt;
      }
    }
    if (latest == null) {
      return;
    }
    await ref.read(announcementStateStoreProvider).markSeen(latest);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(hasUnseen: false, unseenCount: 0);
  }

  Future<void> acknowledgeCritical(Iterable<String> ids) async {
    final acknowledged = ids.toSet();
    await ref.read(announcementStateStoreProvider).acknowledge(acknowledged);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      criticalUnacknowledged: state.criticalUnacknowledged
          .where((item) => !acknowledged.contains(item.id))
          .toList(growable: false),
    );
  }

  void reset() {
    state = AnnouncementFeedState.initial;
  }
}

int _compareAnnouncements(AnnouncementDto left, AnnouncementDto right) {
  final levelComparison = _levelRank(
    left.level,
  ).compareTo(_levelRank(right.level));
  if (levelComparison != 0) {
    return levelComparison;
  }
  return right.publishedAt.compareTo(left.publishedAt);
}

int _levelRank(AnnouncementLevel level) {
  return switch (level) {
    AnnouncementLevel.critical => 0,
    AnnouncementLevel.warning => 1,
    AnnouncementLevel.info => 2,
  };
}
