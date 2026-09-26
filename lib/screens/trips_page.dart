import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/const/app_colors.dart';
import '../core/const/app_dimensions.dart';
import '../core/models/trip.dart';
import '../core/view_models/person_view_model.dart';
import '../core/view_models/trip_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/add_trip_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/trip_card.dart';
import 'trip_detail_page.dart';

/// All group trips: what they spent, who is in them, and what is still owed.
class TripsPage extends StatelessWidget {
  const TripsPage({super.key, this.isTab = false});

  /// When hosted as a tab the page supplies no back button and no app bar of
  /// its own; when pushed as a full screen it does both.
  final bool isTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = context.watch<TripViewModel>();
    final people = context.watch<PersonViewModel>().people;

    // One lookup for the whole list instead of a scan per trip while building.
    final photoPaths = <String, String?>{
      for (final person in people) person.name: person.photoPath,
    };

    final trips = viewModel.trips;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTrip(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n.newTrip,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (!isTab)
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text(
                l10n.trips,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingStandard,
              AppDimensions.spacingSmall,
              AppDimensions.paddingStandard,
              96,
            ),
            sliver: trips.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.luggage_rounded,
                      accentColor: AppColors.accentIndigo,
                      title: l10n.noTripsTitle,
                      description: l10n.noTripsDesc,
                      action: _pillButton(
                        context,
                        label: l10n.newTrip,
                        icon: Icons.add_rounded,
                        onTap: () => _createTrip(context),
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final tripId = trip.key.toString();
                      return TripCard(
                        trip: trip,
                        totalSpent: viewModel.totalSpent(tripId),
                        perPerson: viewModel.averagePerMember(tripId),
                        outstanding: viewModel.outstandingFor(tripId),
                        photoPaths: photoPaths,
                        onTap: () => _openTrip(context, trip),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
          ),
          borderRadius:
              BorderRadius.circular(AppDimensions.borderRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimensions.iconSizeSmall, color: Colors.white),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTrip(BuildContext context) async {
    final trip = await AddTripDialog.show(context);
    if (trip == null || !context.mounted) return;
    await context.read<TripViewModel>().addTrip(trip);
  }

  void _openTrip(BuildContext context, Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailPage(tripId: trip.key.toString())),
    );
  }
}
