import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/widgets/custom_image.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_core/domain/model/tip.dart';
import 'package:neom_core/domain/use_cases/tip_service.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/tip_translation_constants.dart';

/// Displays a horizontal scrollable list of top supporters for a profile.
///
/// The widget fetches supporters from [TipService] and displays them
/// as circular avatars with names and total tip amounts. The top 3
/// supporters are highlighted with medal badges.
class TopSupportersWidget extends StatelessWidget {
  final String profileId;
  final int maxDisplay;

  const TopSupportersWidget({
    super.key,
    required this.profileId,
    this.maxDisplay = 5,
  });

  @override
  Widget build(BuildContext context) {
    final TipService tipService = Sint.find<TipService>();

    return FutureBuilder<List<Tip>>(
      future: tipService.getTopSupporters(profileId, limit: maxDisplay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final List<Tip> supporters = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            AppTheme.heightSpace10,
            supporters.isEmpty
                ? _buildEmptyState()
                : _buildSupportersList(supporters),
          ],
        );
      },
    );
  }

  /// Header row with crown icon and title.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
          const SizedBox(width: 8),
          Text(
            TipTranslationConstants.tipTopSupporters.tr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state when no supporters exist yet.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColor.surfaceDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Text(
          TipTranslationConstants.tipBeFirst.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Horizontal scrollable list of supporter cards.
  Widget _buildSupportersList(List<Tip> supporters) {
    /// Aggregate tips by sender and compute totals.
    final Map<String, _SupporterData> aggregated = {};

    for (final tip in supporters) {
      if (aggregated.containsKey(tip.senderId)) {
        aggregated[tip.senderId]!.totalAmount += tip.amount;
      } else {
        aggregated[tip.senderId] = _SupporterData(
          name: tip.senderName,
          avatarUrl: tip.senderAvatarUrl,
          totalAmount: tip.amount,
        );
      }
    }

    /// Sort by total amount descending and take maxDisplay.
    final List<MapEntry<String, _SupporterData>> sorted =
        aggregated.entries.toList()
          ..sort((a, b) => b.value.totalAmount.compareTo(a.value.totalAmount));

    final List<MapEntry<String, _SupporterData>> topList =
        sorted.take(maxDisplay).toList();

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: topList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final supporter = topList[index].value;
          return _SupporterCard(
            name: supporter.name,
            avatarUrl: supporter.avatarUrl,
            totalAmount: supporter.totalAmount,
            rank: index,
          );
        },
      ),
    );
  }
}

/// Internal data class to aggregate supporter tip totals.
class _SupporterData {
  final String name;
  final String avatarUrl;
  double totalAmount;

  _SupporterData({
    required this.name,
    required this.avatarUrl,
    required this.totalAmount,
  });
}

/// A single supporter avatar card with rank medal, name, and total.
class _SupporterCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final double totalAmount;
  final int rank;

  const _SupporterCard({
    required this.name,
    required this.avatarUrl,
    required this.totalAmount,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              avatarUrl.isNotEmpty
                  ? platformCircleAvatar(
                      imageUrl: avatarUrl,
                      radius: 28,
                      backgroundColor: AppColor.scaffold,
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColor.scaffold,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              if (rank < 3)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColor.getMain(),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _rankMedal,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${totalAmount.truncate()}',
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String get _rankMedal {
    switch (rank) {
      case 0:
        return '\uD83E\uDD47';
      case 1:
        return '\uD83E\uDD48';
      case 2:
        return '\uD83E\uDD49';
      default:
        return '';
    }
  }
}
