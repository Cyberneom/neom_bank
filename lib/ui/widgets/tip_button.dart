import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/tip_translation_constants.dart';
import 'tip_sheet.dart';

/// A reusable button that opens the [TipSheet] bottom sheet.
///
/// Place this widget on artist profiles, posts, or live sessions
/// to allow users to send tips (GigCoins) to the recipient.
class TipButton extends StatelessWidget {
  final String recipientId;
  final String recipientName;
  final String? contextType;
  final String? contextId;
  final bool showLabel;
  final double iconSize;

  const TipButton({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.contextType,
    this.contextId,
    this.showLabel = false,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return showLabel
        ? TextButton.icon(
            onPressed: () => _openTipSheet(context),
            icon: Icon(
              Icons.volunteer_activism,
              color: Colors.amber,
              size: iconSize,
            ),
            label: Text(
              TipTranslationConstants.tipSupport.tr,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : IconButton(
            onPressed: () => _openTipSheet(context),
            icon: Icon(
              Icons.volunteer_activism,
              color: Colors.amber,
              size: iconSize,
            ),
            tooltip: TipTranslationConstants.tipSupport.tr,
            splashColor: AppColor.surfaceDim,
          );
  }

  void _openTipSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TipSheet(
        recipientId: recipientId,
        recipientName: recipientName,
        contextType: contextType,
        contextId: contextId,
      ),
    );
  }
}
