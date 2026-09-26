import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../core/const/app_assets.dart';
import '../core/const/app_dimensions.dart';
import '../core/models/trip_expense.dart';
import '../l10n/generated/app_localizations.dart';
import 'member_avatar.dart';

/// One shared expense in a trip's list: who paid, how it was split, and how
/// much of it still needs paying back.
class TripExpenseTile extends StatelessWidget {
  const TripExpenseTile({
    super.key,
    required this.expense,
    required this.currencySymbol,
    required this.photoPaths,
    required this.onTap,
    required this.onDelete,
  });

  final TripExpense expense;
  final String currencySymbol;
  final Map<String, String?> photoPaths;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const Map<String, String> _categoryIcons = {
    'travel': SvgAppIcons.travelIcon,
    'food': SvgAppIcons.foodIcon,
    'transport': SvgAppIcons.transportIcon,
    'shopping': SvgAppIcons.shoppingIcon,
    'entertainment': SvgAppIcons.entertainmentIcon,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = NumberFormat('#,##0.##');
    final owed = expense.owedToPayer;
    final isSettled = owed <= 0.005;
    final iconPath =
        _categoryIcons[expense.category] ?? SvgAppIcons.genericCategoryIcon;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: ZoomTapAnimation(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadiusXLarge),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.05),
              width: 1.4,
            ),
          ),
          padding: const EdgeInsets.all(AppDimensions.spacingStandard),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusMedium),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: SvgPicture.asset(
                    iconPath,
                    colorFilter: ColorFilter.mode(
                      theme.colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        MemberAvatar(
                          name: expense.paidBy,
                          photoPath: photoPaths[expense.paidBy],
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${expense.paidBy} · '
                            '${DateFormat('MMM d').format(expense.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.28,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currencySymbol${format.format(expense.amount)}',
                        maxLines: 1,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSettled
                        ? '—'
                        : '$currencySymbol${format.format(owed)} ${_backLabel(context)}',
                    maxLines: 1,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSettled
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                iconSize: AppDimensions.iconSizeSmall,
                icon: Icon(
                  Icons.close_rounded,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _backLabel(BuildContext context) =>
      AppLocalizations.of(context)!.toBePaidBack;
}
