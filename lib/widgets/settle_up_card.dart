import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/const/app_colors.dart';
import '../core/const/app_dimensions.dart';
import '../core/models/trip_settlement.dart';
import '../core/services/settlement_calculator.dart';
import '../l10n/generated/app_localizations.dart';
import 'member_avatar.dart';

/// The money side of a trip: each member's standing, the smallest set of
/// payments that closes the trip, and the payments already made.
class SettleUpCard extends StatelessWidget {
  const SettleUpCard({
    super.key,
    required this.balances,
    required this.plan,
    required this.photoPaths,
    required this.nameFor,
    required this.currencySymbol,
    required this.outstanding,
    required this.isSettled,
    required this.settlements,
    required this.onRecord,
    required this.onDeleteSettlement,
  });

  final Map<String, MemberBalance> balances;
  final List<SettlementTransfer> plan;
  /// Photos, keyed by member id, for members who also exist in the People tab.
  final Map<String, String?> photoPaths;

  /// Turns a member id into something a person recognises. Balances and
  /// transfers stay keyed by id — that is what a recorded settlement writes —
  /// so the id is only ever resolved here, for display.
  final String Function(String key) nameFor;

  final String currencySymbol;
  final double outstanding;
  final bool isSettled;
  final List<TripSettlement> settlements;
  final void Function(String from, String to, double amount) onRecord;
  final ValueChanged<TripSettlement> onDeleteSettlement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final format = NumberFormat('#,##0.##');

    // Biggest creditor first — the people the group owes most lead the list.
    final ranked = balances.values.where((b) => !b.isSettledUp).toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingStandard),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXLarge),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.05),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSettled)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.accentGreen,
                    size: AppDimensions.iconSizeMedium),
                const SizedBox(width: AppDimensions.spacingSmall),
                Expanded(
                  child: Text(
                    l10n.allSettledDesc,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              '${l10n.outstanding}: $currencySymbol${format.format(outstanding)}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            for (final balance in ranked)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
                child: _balanceRow(context, balance, format),
              ),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.08)),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                l10n.settleUpDesc,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              for (final transfer in plan)
                _transferRow(context, transfer, format),
            ],
          ],
          if (settlements.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.08)),
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(
              l10n.settlementHistory,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            for (final settlement in settlements)
              _settlementRow(context, settlement, format),
          ],
        ],
      ),
    );
  }

  Widget _balanceRow(
    BuildContext context,
    MemberBalance balance,
    NumberFormat format,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isOwed = balance.net > 0;

    return Row(
      children: [
        MemberAvatar(
          name: balance.name,
          photoPath: photoPaths[balance.name],
          size: AppDimensions.avatar2SizeStandard,
        ),
        const SizedBox(width: AppDimensions.spacingMedium),
        Expanded(
          child: Text(
            nameFor(balance.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currencySymbol${format.format(balance.net.abs())}',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isOwed ? AppColors.accentGreen : AppColors.accentRed,
              ),
            ),
            Text(
              isOwed ? l10n.isOwed : l10n.owes,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transferRow(
    BuildContext context,
    SettlementTransfer transfer,
    NumberFormat format,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                MemberAvatar(
                  name: nameFor(transfer.from),
                  photoPath: photoPaths[transfer.from],
                  size: 24,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    nameFor(transfer.from),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 14,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                MemberAvatar(
                  name: nameFor(transfer.to),
                  photoPath: photoPaths[transfer.to],
                  size: 24,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    nameFor(transfer.to),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSmall),
          Text(
            '$currencySymbol${format.format(transfer.amount)}',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.accentRed,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingXSmall),
          IconButton(
            onPressed: () =>
                onRecord(transfer.from, transfer.to, transfer.amount),
            visualDensity: VisualDensity.compact,
            iconSize: AppDimensions.iconSizeSmall,
            tooltip: l10n.recordSettlement,
            icon: const Icon(Icons.check_circle_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _settlementRow(
    BuildContext context,
    TripSettlement settlement,
    NumberFormat format,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXSmall),
      child: Row(
        children: [
          Icon(Icons.check_rounded,
              size: 14, color: AppColors.accentGreen.withValues(alpha: 0.8)),
          const SizedBox(width: AppDimensions.spacingSmall),
          Expanded(
            child: Text(
              '${nameFor(settlement.fromMember)} → ${nameFor(settlement.toMember)}'
              '  ·  ${DateFormat('MMM d').format(settlement.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            '$currencySymbol${format.format(settlement.amount)}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGreen,
            ),
          ),
          IconButton(
            onPressed: () => onDeleteSettlement(settlement),
            visualDensity: VisualDensity.compact,
            iconSize: AppDimensions.iconSizeXXSmall,
            tooltip: l10n.delete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
