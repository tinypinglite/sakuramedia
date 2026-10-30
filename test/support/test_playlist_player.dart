import 'package:media_kit/media_kit.dart';

class TestPlaylistPlayer extends PlatformPlayer {
  TestPlaylistPlayer() : super(configuration: const PlayerConfiguration());
  final calls = <String>[];
  final properties = <String, String>{};

  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties[property] = value;
    calls.add('property:$property=$value');
  }

  void select(int index, Duration position, {bool playing = true}) {
    state = state.copyWith(
      playlist: state.playlist.copyWith(index: index),
      position: position,
      playing: playing,
    );
    playlistController.add(state.playlist);
    positionController.add(position);
  }

  void reportDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    durationController.add(duration);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    calls.add('open');
    final playlist = playable as Playlist;
    state = state.copyWith(
      playlist: playlist,
      position: playlist.medias[playlist.index].start ?? Duration.zero,
      playing: play,
    );
    playlistController.add(playlist);
    positionController.add(state.position);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    state = state.copyWith(
      playlist: const Playlist([]),
      playing: false,
      position: Duration.zero,
    );
    playlistController.add(state.playlist);
    positionController.add(Duration.zero);
  }

  @override
  Future<void> remove(int index) async {
    calls.add('remove:$index');
    final current = state.playlist.index;
    final medias = state.playlist.medias.toList()..removeAt(index);
    final next = current > index
        ? current - 1
        : current.clamp(0, medias.length - 1);
    state = state.copyWith(
      playlist: Playlist(medias, index: next),
      position: current == index ? Duration.zero : state.position,
    );
    playlistController.add(state.playlist);
  }

  @override
  Future<void> jump(int index) async {
    calls.add('jump:$index');
    select(index, state.playlist.medias[index].start ?? Duration.zero);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    state = state.copyWith(playing: true);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inSeconds}');
    state = state.copyWith(position: position);
    positionController.add(position);
  }
}
