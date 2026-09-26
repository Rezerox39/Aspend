import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../core/const/app_colors.dart';
import '../core/const/app_dimensions.dart';
import '../core/const/app_typography.dart';
import '../core/models/trip.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/view_models/theme_view_model.dart';
import 'member_avatar.dart';

/// One trip in the trips list: cover, title, dates, members, and the two
/// numbers people actually check a trip for.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.totalSpent,
    required this.perPerson,
    required this.outstanding,
    required this.onTap,
    this.photoPaths = const {},
  });

  final Trip trip;
  final double totalSpent;
  final double perPerson;
  final double outstanding;
  final VoidCallback onTap;

  /// Member name -> photo path, so avatars can use the People tab's photos.
  final Map<String, String?> photoPaths;

  static const int _maxStackedAvatars = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currencySymbol =
        context.select<ThemeViewModel, String>((vm) => vm.currencySymbol);

    return ZoomTapAnimation(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              BorderRadius.circular(AppDimensions.borderRadiusXLarge),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.05),
            width: 1.4,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, theme, l10n),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingStandard,
                AppDimensions.spacingMedium,
                AppDimensions.paddingStandard,
                AppDimensions.paddingStandard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _memberStrip(context, theme),
                  const SizedBox(height: AppDimensions.spacingStandard),
                  _totals(context, theme, l10n, currencySymbol),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final subtitle = _subtitle();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingStandard),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            AppColors.accentIndigo.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppDimensions.borderRadiusMedium),
            ),
            child: Icon(
              trip.isArchived
                  ? Icons.inventory_2_outlined
                  : Icons.luggage_rounded,
              color: theme.colorScheme.primary,
              size: AppDimensions.iconSizeLarge,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: AppTypography.fontSizeXSmall,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (trip.isArchived)
            Icon(
              Icons.archive_rounded,
              size: AppDimensions.iconSizeSmall,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
        ],
      ),
    );
  }

  String _subtitle() {
    final start = DateFormat('MMM d').format(trip.startDate);
    final end = trip.endDate;
    final range = end == null
        ? start
        : (DateFormat('MMM d').format(end) == DateFormat('MMM d').format(trip.startDate)
            ? start
            : '$start – ${DateFormat('MMM d').format(end)}');
    if (trip.destination == null || trip.destination!.isEmpty) return range;
    return '${trip.destination} • $range';
  }

  Widget _memberStrip(BuildContext context, ThemeData theme) {
    final shown = trip.memberNames.take(_maxStackedAvatars).toList();
    final overflow = trip.memberNames.length - shown.length;

    return SizedBox(
      height: AppDimensions.avatar2SizeStandard,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (AppDimensions.avatar2SizeStandard - 10),
              child: MemberAvatar(
                name: shown[i],
                photoPath: photoPaths[shown[i]],
                size: AppDimensions.avatar2SizeStandard,
                borderColor: theme.colorScheme.surface,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * (AppDimensions.avatar2SizeStandard - 10),
              child: Container(
                width: AppDimensions.avatar2SizeStandard,
                height: AppDimensions.avatar2SizeStandard,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totals(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    String currencySymbol,
  ) {
    final isSettled = outstanding <= 0.005;

    return Row(
      children: [
        Expanded(
          child: _stat(
            context,
            label: l10n.tripTotalSpent,
            value:
                '$currencySymbol${NumberFormat('#,##0.##').format(totalSpent)}',
            color: theme.colorScheme.onSurface,
          ),
        ),
        Expanded(
          child: _stat(
            context,
            label: l10n.perPerson,
            value:
                '$currencySymbol${NumberFormat('#,##0.##').format(perPerson)}',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        _stat(
          context,
          label: l10n.outstanding,
          value: isSettled
              ? l10n.allSettled
              : '$currencySymbol${NumberFormat('#,##0.##').format(outstanding)}',
          color: isSettled ? AppColors.accentGreen : AppColors.accentRed,
        ),
      ],
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
