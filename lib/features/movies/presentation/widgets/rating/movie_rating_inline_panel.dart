import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/rating/rating_dimension_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_rating_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/rating_dimensions_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/rating/rating_dimensions_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 详情信息块内的评分面板：5 分制点星即保存，10/100 分制点数值后编辑保存。
class MovieRatingInlinePanel extends ConsumerStatefulWidget {
  const MovieRatingInlinePanel({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<MovieRatingInlinePanel> createState() =>
      _MovieRatingInlinePanelState();
}

class _MovieRatingInlinePanelState
    extends ConsumerState<MovieRatingInlinePanel> {
  final Map<int, int> _values = <int, int>{};
  bool _initialized = false;
  bool _dirty = false;
  Future<void>? _saveInFlight;

  Map<int, int> _effectiveValues(List<RatingDimensionDto> dimensions) {
    final validIds = {for (final dimension in dimensions) dimension.id};
    return {
      for (final entry in _values.entries)
        if (validIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void _toggleScore(RatingDimensionDto dimension, int score) {
    _setScore(dimension, _values[dimension.id] == score ? null : score);
  }

  void _setScore(RatingDimensionDto dimension, int? score) {
    setState(() {
      if (score == null) {
        _values.remove(dimension.id);
      } else {
        _values[dimension.id] = score;
      }
    });
    _queueSave();
  }

  void _queueSave() {
    if (_saveInFlight != null) {
      _dirty = true;
      return;
    }
    _saveInFlight = _runSave();
  }

  Future<void> _runSave() async {
    final movieNumber = widget.movieNumber;
    do {
      if (!mounted || widget.movieNumber != movieNumber) {
        break;
      }
      _dirty = false;
      final dimensions =
          ref.read(ratingDimensionsProvider).value ??
          const <RatingDimensionDto>[];
      final values = _effectiveValues(dimensions);
      try {
        final notifier = ref.read(movieRatingProvider(movieNumber).notifier);
        if (values.isEmpty) {
          await notifier.delete();
        } else {
          await notifier.save(values);
        }
      } catch (error) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          showToast(
            apiErrorMessage(
              error,
              fallback: l10n.movieWidgetRatingSaveFailed,
              l10n: l10n,
            ),
          );
        }
        break;
      }
    } while (_dirty && mounted && widget.movieNumber == movieNumber);
    _saveInFlight = null;
  }

  @override
  void didUpdateWidget(covariant MovieRatingInlinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieNumber != widget.movieNumber) {
      _values.clear();
      _initialized = false;
      _dirty = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensionsState = ref.watch(ratingDimensionsProvider);
    final ratingState = ref.watch(movieRatingProvider(widget.movieNumber));
    final dimensions = dimensionsState.value;
    final rating = ratingState.value;

    // 失败态没有值，不能标记已初始化：否则重试成功后旧评分不会回填，
    // 下一次点星只提交单个维度，后端全量替换会抹掉其它维度。
    if (!_initialized && dimensions != null && ratingState.hasValue) {
      _values
        ..clear()
        ..addAll(<int, int>{
          if (rating != null)
            for (final value in rating.values)
              if (dimensions.any((item) => item.id == value.dimensionId))
                value.dimensionId: value.value,
        });
      _initialized = true;
    }

    if (dimensionsState.isLoading && dimensions == null) {
      return _mutedText(
        context,
        AppLocalizations.of(context).movieWidgetLoading,
      );
    }
    if (dimensionsState.hasError && dimensions == null) {
      return _errorLine(
        context,
        AppLocalizations.of(context).movieWidgetRatingDimensionsLoadFailed,
        () => ref.invalidate(ratingDimensionsProvider),
      );
    }
    if (dimensions == null || dimensions.isEmpty) {
      return _messageLine(
        context,
        AppLocalizations.of(context).movieWidgetNoRatingDimensions,
        action: AppLocalizations.of(context).movieWidgetSetupAction,
        onAction: () => showRatingDimensionsDialog(context, ref: ref),
      );
    }
    if (ratingState.isLoading && rating == null) {
      return _mutedText(
        context,
        AppLocalizations.of(context).movieWidgetRatingLoading,
      );
    }
    if (ratingState.hasError && rating == null) {
      return _errorLine(
        context,
        AppLocalizations.of(context).movieWidgetRatingLoadFailed,
        () => ref.invalidate(movieRatingProvider(widget.movieNumber)),
      );
    }
    // 一行能放下几个就并排几个，放不下自动换行。
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        for (final dimension in dimensions) _buildDimension(context, dimension),
      ],
    );
  }

  Widget _buildDimension(BuildContext context, RatingDimensionDto dimension) {
    final value = _values[dimension.id];
    return Row(
      key: Key('movie-rating-dimension-${dimension.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            dimension.name,
            key: Key('movie-rating-name-${dimension.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(context, size: AppTextSize.s12),
          ),
        ),
        SizedBox(width: context.appSpacing.xs),
        if (dimension.maxValue <= 5)
          Row(
            key: Key('movie-rating-stars-${dimension.id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var score = dimension.minValue;
                score <= dimension.maxValue;
                score++
              )
                AppInteractiveSurface(
                  key: Key('movie-rating-score-${dimension.id}-$score'),
                  onTap: () => _toggleScore(dimension, score),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.appSpacing.xs / 2,
                      vertical: context.appSpacing.xs,
                    ),
                    child: Icon(
                      score <= (value ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: context.appComponentTokens.iconSizeMd,
                      color: score <= (value ?? 0)
                          ? context.appColors.movieDetailScoreIcon
                          : context.appTextPalette.muted,
                    ),
                  ),
                ),
            ],
          )
        else
          _NumericScoreValue(
            key: ValueKey('${widget.movieNumber}-${dimension.id}'),
            dimension: dimension,
            value: value,
            onChanged: (nextValue) => _setScore(dimension, nextValue),
          ),
      ],
    );
  }

  Widget _mutedText(BuildContext context, String text) {
    return Text(
      text,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.muted,
      ),
    );
  }

  Widget _errorLine(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    return Wrap(
      spacing: context.appSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.error,
          ),
        ),
        AppTextButton(
          label: AppLocalizations.of(context).commonRetry,
          size: AppTextButtonSize.xSmall,
          onPressed: onRetry,
        ),
      ],
    );
  }

  Widget _messageLine(
    BuildContext context,
    String message, {
    required String action,
    required VoidCallback onAction,
  }) {
    return Wrap(
      spacing: context.appSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        AppTextButton(
          label: action,
          size: AppTextButtonSize.xSmall,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _NumericScoreValue extends StatefulWidget {
  const _NumericScoreValue({
    super.key,
    required this.dimension,
    required this.value,
    required this.onChanged,
  });

  final RatingDimensionDto dimension;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumericScoreValue> createState() => _NumericScoreValueState();
}

class _NumericScoreValueState extends State<_NumericScoreValue> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _NumericScoreValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && widget.value != oldWidget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    if (_editing) {
      return;
    }
    setState(() {
      _editing = true;
      _controller.text = widget.value?.toString() ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) {
        return;
      }
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _finishEditing() {
    if (!mounted || !_editing) {
      return;
    }
    final text = _controller.text.trim();
    final score = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty &&
        (score == null ||
            score < widget.dimension.minValue ||
            score > widget.dimension.maxValue)) {
      showToast(
        AppLocalizations.of(context).movieWidgetRatingScoreInvalid(
          widget.dimension.minValue,
          widget.dimension.maxValue,
        ),
      );
      _controller.text = widget.value?.toString() ?? '';
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    if (score != widget.value) {
      widget.onChanged(score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suffixStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      tone: AppTextTone.muted,
    );
    if (_editing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 28,
            child: TextField(
              key: Key('movie-rating-score-${widget.dimension.id}-field'),
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  widget.dimension.maxValue.toString().length,
                ),
              ],
              onTapOutside: (_) => _focusNode.unfocus(),
              onSubmitted: (_) => _focusNode.unfocus(),
              textAlignVertical: TextAlignVertical.center,
              style: resolveAppTextStyle(context, size: AppTextSize.s12),
              cursorColor: context.appTextPalette.accent,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          SizedBox(width: context.appSpacing.xs / 2),
          Text('/${widget.dimension.maxValue}', style: suffixStyle),
        ],
      );
    }
    return Tooltip(
      message: AppLocalizations.of(context).commonEdit,
      child: AppInteractiveSurface(
        key: Key('movie-rating-value-${widget.dimension.id}'),
        onTap: _startEditing,
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.xs / 2,
            ),
            child: Align(
              alignment: Alignment.center,
              child: widget.value == null
                  ? Text(
                      AppLocalizations.of(context).movieWidgetRatingUnrated,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    )
                  : Text(
                      '${widget.value}/${widget.dimension.maxValue}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.primary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
