import 'package:flutter/foundation.dart';

/// [playlistsOverviewProvider] 的 family 参数：定位「哪一份播放列表概览」。
///
/// [orderScopeKey]：非空时用于 [PlaylistOrderStore] 持久化拖排顺序。同一账号
/// 在同一 NAS 下的多个入口用相同 baseUrl 作 key，共享同一份顺序；null 则不
/// 持久化顺序。
@immutable
class PlaylistsOverviewScope {
  const PlaylistsOverviewScope({this.orderScopeKey});

  final String? orderScopeKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistsOverviewScope && other.orderScopeKey == orderScopeKey);

  @override
  int get hashCode => orderScopeKey.hashCode;
}
