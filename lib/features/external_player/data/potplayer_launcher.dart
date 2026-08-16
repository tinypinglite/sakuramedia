/// PotPlayer 拉起能力：按平台选择实现。
library;

export 'potplayer_launcher_stub.dart'
    if (dart.library.js_interop) 'potplayer_launcher_web.dart'
    if (dart.library.io) 'potplayer_launcher_io.dart';
