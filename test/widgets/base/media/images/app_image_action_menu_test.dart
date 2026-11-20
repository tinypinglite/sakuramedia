import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';

void main() {
  test('图片动作只在语义分组起点画线', () {
    final items = buildImageActionMenuItems(<AppImageActionDescriptor>[
      _descriptor(AppImageActionType.searchSimilar),
      _descriptor(AppImageActionType.saveToLocal),
      _descriptor(AppImageActionType.toggleMark),
      _descriptor(AppImageActionType.addToCollection),
      _descriptor(AppImageActionType.play),
      _descriptor(AppImageActionType.setCover),
      _descriptor(AppImageActionType.movieDetail),
    ]);

    expect(
      items.where((item) => item.showDividerBefore).map((item) => item.value),
      <AppImageActionType>[
        AppImageActionType.addToCollection,
        AppImageActionType.setCover,
      ],
    );
  });

  test('没有设封面动作时详情动作承接最后一组', () {
    final items = buildImageActionMenuItems(<AppImageActionDescriptor>[
      _descriptor(AppImageActionType.searchSimilar),
      _descriptor(AppImageActionType.addToCollection),
      _descriptor(AppImageActionType.play),
      _descriptor(AppImageActionType.movieDetail),
    ]);

    expect(
      items.where((item) => item.showDividerBefore).map((item) => item.value),
      <AppImageActionType>[
        AppImageActionType.addToCollection,
        AppImageActionType.movieDetail,
      ],
    );
  });
}

AppImageActionDescriptor _descriptor(AppImageActionType type) {
  return AppImageActionDescriptor(
    type: type,
    label: type.name,
    icon: Icons.radio_button_unchecked,
  );
}
