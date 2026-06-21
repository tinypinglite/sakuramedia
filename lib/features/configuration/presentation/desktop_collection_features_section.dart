import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/forms/app_info_pill.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class CollectionFeaturesSection extends StatefulWidget {
  const CollectionFeaturesSection({super.key, required this.active});

  final bool active;

  @override
  State<CollectionFeaturesSection> createState() =>
      _CollectionFeaturesSectionState();
}

class _CollectionFeaturesSectionState extends State<CollectionFeaturesSection> {
  late final TextEditingController _collectionNumberFeaturesController;

  bool _initialized = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _applySyncNow = true;
  String? _errorMessage;
  CollectionNumberFeaturesSyncStatsDto? _syncStats;

  @override
  void initState() {
    super.initState();
    _collectionNumberFeaturesController = TextEditingController();
    if (widget.active) {
      _loadFeatures();
    }
  }

  @override
  void didUpdateWidget(covariant CollectionFeaturesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadFeatures();
    }
  }

  @override
  void dispose() {
    _collectionNumberFeaturesController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings =
          await context.read<CollectionNumberFeaturesApi>().getFeatures();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyFeatures(settings);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '合集番号特征加载失败，请稍后重试。');
      });
    }
  }

  void _applyFeatures(CollectionNumberFeaturesDto settings) {
    _collectionNumberFeaturesController.text = settings.features.join('\n');
    _syncStats = settings.syncStats;
  }

  Future<void> _saveFeatures() async {
    if (_isSaving) {
      return;
    }

    final features = _parseFeaturesInput(
      _collectionNumberFeaturesController.text,
    );

    setState(() {
      _isSaving = true;
    });
    try {
      final settings = await context
          .read<CollectionNumberFeaturesApi>()
          .updateFeatures(
            UpdateCollectionNumberFeaturesPayload(features: features),
            applyNow: _applySyncNow,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyFeatures(settings);
        _errorMessage = null;
        _isSaving = false;
      });
      showToast(_applySyncNow ? '已保存并完成合集重算' : '合集番号特征已保存');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      showToast(apiErrorMessage(error, fallback: '保存合集番号特征失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const AppSectionSkeleton(lineCount: 5);
    }

    if (_errorMessage != null) {
      return AppSectionError(
        title: '合集番号特征加载失败',
        message: _errorMessage!,
        onRetry: _loadFeatures,
      );
    }

    final syncStats = _syncStats;
    final spacing = context.appSpacing;

    return AppContentCard(
      title: '合集番号特征',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每行输入一个番号特征，用于判定影片是否为合集。保存时可选择是否立即触发全库重算。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          AppTextField(
            fieldKey: const Key('configuration-collection-features-field'),
            controller: _collectionNumberFeaturesController,
            maxLines: 8,
            minLines: 6,
            hintText: '例如:\nFC2\nOFJE\nDVAJ',
          ),
          SizedBox(height: spacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '保存后动作',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 260,
                      child: AppSelectField<bool>(
                        key: const Key(
                          'configuration-collection-apply-now-field',
                        ),
                        value: _applySyncNow,
                        size: AppSelectFieldSize.compact,
                        items: const [
                          DropdownMenuItem<bool>(
                            value: true,
                            child: Text('保存并立即重算合集'),
                          ),
                          DropdownMenuItem<bool>(
                            value: false,
                            child: Text('仅保存特征配置'),
                          ),
                        ],
                        onChanged:
                            (value) => setState(() {
                              _applySyncNow = value ?? true;
                            }),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    SizedBox(
                      width: 260,
                      child: AppButton(
                        key: const Key(
                          'configuration-collection-features-save-button',
                        ),
                        onPressed: _isSaving ? null : _saveFeatures,
                        icon:
                            _isSaving ? null : const Icon(Icons.save_outlined),
                        label: _isSaving ? '保存中' : '保存特征',
                        variant: AppButtonVariant.primary,
                        isLoading: _isSaving,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (syncStats != null) ...[
            SizedBox(height: spacing.lg),
            Text(
              '最近一次即时重算结果',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                AppInfoPill(label: '影片总数', value: '${syncStats.totalMovies}'),
                AppInfoPill(label: '匹配数量', value: '${syncStats.matchedCount}'),
                AppInfoPill(
                  label: '更新为合集',
                  value: '${syncStats.updatedToCollectionCount}',
                ),
                AppInfoPill(
                  label: '更新为单体',
                  value: '${syncStats.updatedToSingleCount}',
                ),
                AppInfoPill(label: '未变化', value: '${syncStats.unchangedCount}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _parseFeaturesInput(String rawValue) {
  return rawValue
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
