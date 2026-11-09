import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

/// 页面内和顶栏玻璃搜索框共用的 [AppTextField] 外壳。
///
/// 调用方保留各自的尺寸、焦点和前后缀语义；玻璃质感、字体、高对比度和
/// 动效统一由 [AppTextField] 提供。
Widget buildAppGlassSearchField({
  Key? key,
  required BuildContext context,
  required TextEditingController controller,
  required String placeholder,
  required double height,
  FocusNode? focusNode,
  Widget? prefixIcon,
  Widget? suffixIcon,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  AppGlassTone glassTone = AppGlassTone.standard,
}) {
  return AppTextField(
    fieldKey: key,
    controller: controller,
    focusNode: focusNode,
    hintText: placeholder,
    prefix: prefixIcon,
    suffix: suffixIcon,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    height: height,
    contentPadding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
    borderRadius: BorderRadius.circular(height / 2),
    glassTone: glassTone,
  );
}
