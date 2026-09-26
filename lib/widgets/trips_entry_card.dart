import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../core/const/app_colors.dart';
import '../core/const/app_dimensions.dart';
import '../core/view_models/theme_view_model.dart';
import '../core/view_models/trip_view_model.dart';
import '../l10n/generated/app_localizations.dart';

/// Entry point into group trips, shown at the top of the People tab.
///
/// Trips live here rather than in their own tab because a trip is made of
/// people: members are picked from the People list, and the People tab is
/// where someone already is when they think "we're splitting this".
class TripsEntryCard extends StatelessWidget {
  const TripsEntryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currencySymbol =
        context.select<ThemeViewModel, String>((vm) => vm.currencySymbol);
    final tripCount = context.select<TripViewModel, int>((vm) => vm.trips.length);
    final outstanding = context.select<TripViewModel, double>((vm) {
      var total = 0.0;
      for (final trip in vm.trips) {
        total += vm.outstandingFor(trip.key.toString());
      }
      return total;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingStandard,
        AppDimensions.spacingSmall,
        AppDimensions.paddingStandard,
        0,
      ),
      child: ZoomTapAnimation(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingStandard),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentIndigo.withValues(alpha: 0.18),
                AppColors.accentIndigoDeep.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: AppColors.accentIndigo.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentIndigo.withValues(alpha: 0.14),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusMedium),
                ),
                child: const Icon(
                  Icons.luggage_rounded,
                  color: AppColors.accentIndigo,
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
                      l10n.trips,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tripCount == 0
                          ? l10n.noTripsDesc
                          : outstanding > 0.005
                              ? '${l10n.outstanding}: '
                                  '$currencySymbol${outstanding.toStringAsFixed(0)}'
                              : l10n.allSettled,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
