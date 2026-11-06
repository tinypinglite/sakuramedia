import 'package:cupertino_ui/cupertino_ui.dart';

/// 滚动末尾补出的底部安全区留白节点的 key（`bottomSafeAreaSliver` 产出）。
///
/// 断言「滚到底时最后一块内容停在 home indicator 之上」靠它取位置。
const Key bottomSafeAreaScrollInsetKey = Key(
  'app-scroll-bottom-safe-area-inset',
);

/// 滚动内容末尾补出的底部安全区留白（sliver 形式）。
///
/// 移动子页外壳不吞底部安全区：内容铺到屏幕物理底边，滚动页要在末尾自己补回
/// 等高留白，否则最后一块内容会被 home indicator 压住。根 Tab 壳的玻璃底栏
/// 开启 `extendBody` 后，这里读到的是「底栏 + 系统安全区」的总高度，用来让
/// 最后一项停在 Dock 上方；桌面和底抽屉里读到的是 0，返回空列表。
///
/// `AppAdaptiveRefreshScrollView` 已内置这段留白；自建 `CustomScrollView`
/// 的页面把返回值追加到 `slivers` 末尾即可。
List<Widget> bottomSafeAreaSliver(BuildContext context) {
  final inset = MediaQuery.paddingOf(context).bottom;
  return inset <= 0
      ? const <Widget>[]
      : <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(key: bottomSafeAreaScrollInsetKey, height: inset),
          ),
        ];
}
