import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/cast/data/cast_session.dart';

part 'cast_session_provider.g.dart';

/// 进行中的投屏会话（内存态，跨页面共享；App 重启后丢失）。
@Riverpod(keepAlive: true)
class CastSessionController extends _$CastSessionController {
  @override
  CastSession? build() => null;

  void start(CastSession session) => state = session;

  void clear() => state = null;
}
