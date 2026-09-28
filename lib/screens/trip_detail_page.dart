import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/const/app_currencies.dart';
import '../core/const/app_colors.dart';
import '../core/const/app_dimensions.dart';
import '../core/const/app_typography.dart';
import '../core/models/trip.dart';
import '../core/models/trip_expense.dart';
import '../core/models/trip_settlement.dart';
import '../core/view_models/person_view_model.dart';
import '../core/view_models/trip_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/add_trip_dialog.dart';
import '../widgets/add_trip_expense_dialog.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/settle_up_card.dart';
import '../widgets/trip_expense_tile.dart';

/// One trip in full: headline numbers, who owes whom, and every shared expense.
class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final viewModel = context.watch<TripViewModel>();
    final trip = viewModel.tripByKey(tripId);

    // The trip can disappear underneath us (deleted from another surface), so
    // guard rather than dereferencing null.
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noTripsTitle)),
      );
    }

    // A trip owns its members now, so photos are an optional extra borrowed
    // from the People tab by name — keyed by member id like everything else.
    final people = context.watch<PersonViewModel>().people;
    final photosByName = <String, String?>{
      for (final person in people) person.name: person.photoPath,
    };
    final photoPaths = <String, String?>{
      for (final member in trip.effectiveMembers)
        member.id: photosByName[member.name],
    };
    // Balances are held in the trip's own base currency.
    final currencySymbol = AppCurrencies.byCode(trip.baseCurrency).symbol;

    final expenses = viewModel.expensesFor(tripId);
    final balances = viewModel.balancesFor(tripId);
    final plan = viewModel.settleUpPlan(tripId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExpense(context, trip, photoPaths),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(
          l10n.addTripExpense,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _dateRange(context, trip),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: trip.isArchived ? l10n.unarchiveTrip : l10n.archiveTrip,
                onPressed: () =>
                    viewModel.setTripArchived(trip, !trip.isArchived),
                icon: Icon(
                  trip.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: AppDimensions.iconSizeMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.editTrip,
                onPressed: () => _editTrip(context, trip),
                icon: const Icon(Icons.edit_outlined,
                    size: AppDimensions.iconSizeMedium),
              ),
              IconButton(
                tooltip: l10n.deleteTrip,
                onPressed: () => _confirmDelete(context, trip),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: AppDimensions.iconSizeMedium),
              ),
            ],
          ),
          // The summary and settle-up block are fixed-height, so they sit in
          // their own slivers. The expense list below is the part that can
          // grow without bound on a long trip, so it gets a lazy builder
          // rather than being materialised up front.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingStandard,
              AppDimensions.spacingSmall,
              AppDimensions.paddingStandard,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summary(context, trip, viewModel, currencySymbol),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  _sectionTitle(context, l10n.settleUpTitle),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  SettleUpCard(
                    balances: balances,
                    plan: plan,
                    photoPaths: photoPaths,
                    nameFor: trip.nameOf,
                    currencySymbol: currencySymbol,
                    outstanding: viewModel.outstandingFor(tripId),
                    isSettled: viewModel.isFullySettled(tripId),
                    settlements: viewModel.settlementsFor(tripId),
                    onRecord: (from, to, amount) => _recordSettlement(
                      context,
                      trip,
                      from: from,
                      to: to,
                      amount: amount,
                    ),
                    onDeleteSettlement: (settlement) =>
                        viewModel.deleteSettlement(settlement),
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  _sectionTitle(context, l10n.tripExpenses),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  if (expenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: EmptyStateView(
                        icon: Icons.receipt_long_rounded,
                        accentColor: AppColors.accentAmber,
                        title: l10n.noExpensesTitle,
                        description: l10n.noExpensesDesc,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (expenses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingStandard,
                0,
                AppDimensions.paddingStandard,
                96,
              ),
              sliver: SliverList.builder(
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return RepaintBoundary(
                    child: TripExpenseTile(
                      expense: expense,
                      currencySymbol: currencySymbol,
                      photoPaths: photoPaths,
                      onTap: () =>
                          _editExpense(context, trip, expense, photoPaths),
                      onDelete: () => viewModel.deleteExpense(expense),
                    ),
                  );
                },
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: AppTypography.fontSizeMedium,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );

  String _dateRange(BuildContext context, Trip trip) {
    final start = DateFormat('MMM d, yyyy').format(trip.startDate);
    if (trip.endDate == null) {
      return '$start – ${AppLocalizations.of(context)!.ongoing}';
    }
    return '$start – ${DateFormat('MMM d, yyyy').format(trip.endDate!)}';
  }

  Widget _summary(
    BuildContext context,
    Trip trip,
    TripViewModel viewModel,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final format = NumberFormat('#,##0.##');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXLarge),
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
          Expanded(
            child: _summaryStat(
              context,
              label: l10n.tripTotalSpent,
              value: '$currencySymbol${format.format(viewModel.totalSpent(trip.key.toString()))}',
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: _summaryStat(
              context,
              label: l10n.perPerson,
              value:
                  '$currencySymbol${format.format(viewModel.averagePerMember(trip.key.toString()))}',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          Expanded(
            child: _summaryStat(
              context,
              label: l10n.outstanding,
              value: viewModel.isFullySettled(trip.key.toString())
                  ? l10n.allSettled
                  : '$currencySymbol${format.format(viewModel.outstandingFor(trip.key.toString()))}',
              color: viewModel.isFullySettled(trip.key.toString())
                  ? AppColors.accentGreen
                  : AppColors.accentRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addExpense(
    BuildContext context,
    Trip trip,
    Map<String, String?> photoPaths,
  ) async {
    final expense = await AddTripExpenseDialog.show(
      context,
      trip: trip,
      photoPaths: photoPaths,
    );
    if (expense == null || !context.mounted) return;
    await context.read<TripViewModel>().addExpense(expense);
  }

  Future<void> _editExpense(
    BuildContext context,
    Trip trip,
    TripExpense expense,
    Map<String, String?> photoPaths,
  ) async {
    final updated = await AddTripExpenseDialog.show(
      context,
      trip: trip,
      existingExpense: expense,
      photoPaths: photoPaths,
    );
    if (updated == null || !context.mounted) return;
    await context.read<TripViewModel>().updateExpense(expense, updated);
  }

  Future<void> _editTrip(BuildContext context, Trip trip) async {
    final updated = await AddTripDialog.show(context, existingTrip: trip);
    if (updated == null || !context.mounted) return;
    await context.read<TripViewModel>().updateTrip(trip, updated);
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.borderRadiusXLarge),
        ),
        title: Text(l10n.deleteTrip, style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
        )),
        content: Text(l10n.deleteTripDesc, style: GoogleFonts.dmSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<TripViewModel>().deleteTrip(trip);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _recordSettlement(
    BuildContext context,
    Trip trip, {
    required String from,
    required String to,
    required double amount,
  }) async {
    final settlement = TripSettlement(
      tripId: trip.key.toString(),
      fromMember: from,
      toMember: to,
      amount: amount,
      date: DateTime.now(),
    );
    await context.read<TripViewModel>().addSettlement(settlement);
  }
}
