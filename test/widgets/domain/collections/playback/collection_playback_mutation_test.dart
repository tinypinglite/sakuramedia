import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_filmstrip_controller.dart';
import 'package:sakuramedia/widgets/domain/collections/playback/collection_playback_page_mixin.dart';
import 'package:sakuramedia/widgets/domain/movies/player/merged_position_indicator.dart';
import '../../../../support/test_playlist_player.dart';

class _VideoController extends Fake implements VideoController {}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.player});
  final Player player;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with CollectionPlaybackPageMixin<_Harness> {
  int removed = 0;
  @override
  void initState() {
    super.initState();
    attachPlayback(
      player: widget.player,
      videoController: _VideoController(),
      filmstrip: CollectionFilmstripController(
        episodeCount: 3,
        frameLoader: (_) async => [],
      ),
      startIndex: widget.player.state.playlist.index,
      episodeDurationsSeconds: [600, 1200, 1800],
    );
  }

  Future<void> remove(
    int index, {
    bool delete = false,
    Future<void> Function()? persist,
  }) => removePlaybackEpisode(
    index,
    deleteMedia: delete,
    persist: persist ?? () async {},
    onRemoved: () => removed++,
  );
  @override
  void dispose() {
    disposePlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        MergedPositionIndicator(
          player: widget.player,
          episodeDurationsSeconds: episodeDurationsSeconds,
          onSeekGlobalSeconds: seekToGlobalSeconds,
        ),
      ],
    ),
  );
}

void main() {
  late TestPlaylistPlayer native;
  late GlobalKey<_HarnessState> key;
  Future<void> mount(
    WidgetTester tester, {
    int index = 2,
    bool playing = true,
  }) async {
    native = TestPlaylistPlayer();
    await native.open(
      Playlist([
        for (var i = 0; i < 3; i++) Media('https://example.test/$i.mp4'),
      ], index: index),
    );
    native.select(index, const Duration(minutes: 5), playing: playing);
    native.calls.clear();
    key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: _Harness(
          key: key,
          player: Player(platformPlayer: native),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('移出前集保留当前源、集内位置与暂停状态，并重算合并进度', (tester) async {
    await mount(tester, playing: false);
    await key.currentState!.remove(0);
    await tester.pump();
    expect(native.calls, ['remove:0']);
    expect(native.state.playlist.index, 1);
    expect(native.state.position, const Duration(minutes: 5));
    expect(native.state.playing, false);
    final slider = tester.widget<Slider>(
      find.byKey(const Key('merged-position-indicator-slider')),
    );
    expect(slider.value, 1500);
    expect(slider.max, 3000);
  });
  testWidgets('持久化失败不移除队列，不中断非目标当前媒体', (tester) async {
    await mount(tester);
    await expectLater(
      key.currentState!.remove(
        0,
        persist: () async => throw StateError('offline'),
      ),
      throwsStateError,
    );
    await tester.pump();
    expect(native.calls, isEmpty);
    expect(key.currentState!.removed, 0);
    expect(key.currentState!.episodeDurationsSeconds, [600, 1200, 1800]);
    expect(native.state.playlist.medias, hasLength(3));
  });
  testWidgets('删除失败恢复暂停位置，再次切回原集从头播放', (tester) async {
    await mount(tester, index: 1, playing: false);
    await expectLater(
      key.currentState!.remove(
        1,
        delete: true,
        persist: () async {
          expect(native.calls, ['stop']);
          throw StateError('offline');
        },
      ),
      throwsStateError,
    );
    await tester.pump();
    expect(native.calls, ['stop', 'open']);
    native.reportDuration(Duration.zero);
    await tester.pump();
    expect(native.calls, ['stop', 'open']);
    native.reportDuration(const Duration(minutes: 20));
    await tester.pump();
    expect(native.state.playlist.index, 1);
    expect(native.state.position, const Duration(minutes: 5));
    expect(native.state.playing, false);
    expect(key.currentState!.removed, 0);
    await key.currentState!.jumpTo(0);
    await key.currentState!.jumpTo(1);
    await tester.pump();
    expect(native.state.position, Duration.zero);
  });
  for (final delete in [false, true]) {
    testWidgets('${delete ? '删除' : '移出'}当前集后转下一集，保留暂停状态', (tester) async {
      await mount(tester, index: 1, playing: false);
      await key.currentState!.remove(1, delete: delete);
      await tester.pump();
      expect(
        native.state.playlist.medias[native.state.playlist.index].uri,
        endsWith('/2.mp4'),
      );
      expect(native.state.position, Duration.zero);
      expect(native.state.playing, false);
      expect(key.currentState!.episodeDurationsSeconds, [600, 1800]);
    });
    testWidgets('${delete ? '删除' : '移出'}末集后上一集从头暂停，最后一集后清空', (tester) async {
      await mount(tester);
      await key.currentState!.remove(2, delete: delete);
      expect(native.state.playlist.index, 1);
      expect(native.state.position, Duration.zero);
      expect(native.state.playing, false);
      await key.currentState!.remove(1, delete: delete);
      await key.currentState!.remove(0, delete: delete);
      await tester.pump();
      expect(native.state.playlist.medias, isEmpty);
      expect(key.currentState!.episodeDurationsSeconds, isEmpty);
      expect(key.currentState!.filmstrip!.thumbnails, isEmpty);
      final slider = tester.widget<Slider>(
        find.byKey(const Key('merged-position-indicator-slider')),
      );
      expect(slider.onChanged, isNull);
      expect(slider.value, 0);
    });
  }
  testWidgets('接口等待时自动换集，成功后按实时当前集定位且屏蔽重复提交', (tester) async {
    await mount(tester, index: 1);
    final pending = Completer<void>();
    final operation = key.currentState!.remove(
      1,
      persist: () => pending.future,
    );
    await key.currentState!.remove(0);
    native.select(2, const Duration(seconds: 7));
    pending.complete();
    await operation;
    await tester.pump();
    expect(key.currentState!.removed, 1);
    expect(native.calls, ['remove:1']);
    expect(native.state.playlist.index, 1);
    expect(native.state.position.inSeconds, 7);
  });
  testWidgets('队列改变取消正在拖动的旧时间轴值', (tester) async {
    await mount(tester);
    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(3500);
    await tester.pump();
    await key.currentState!.remove(0);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 1500);
  });
}
