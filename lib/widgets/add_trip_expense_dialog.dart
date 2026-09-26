import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/const/app_assets.dart';
import '../core/const/app_dimensions.dart';
import '../core/models/trip.dart';
import '../core/models/trip_expense.dart';
import '../core/services/settlement_calculator.dart';
import '../core/utils/blur_utils.dart';
import '../core/view_models/theme_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import 'member_avatar.dart';

/// Add or edit a shared expense and decide how it splits.
///
/// The per-member rows are driven by [SettlementCalculator.buildShares], so
/// what the user sees while editing is exactly what gets saved — including the
/// rounding, so a 3-way split of ₹100 never quietly loses a rupee.
class AddTripExpenseDialog extends StatefulWidget {
  const AddTripExpenseDialog({
    super.key,
    required this.trip,
    this.existingExpense,
    this.photoPaths = const {},
  });

  final Trip trip;
  final TripExpense? existingExpense;
  final Map<String, String?> photoPaths;

  static Future<TripExpense?> show(
    BuildContext context, {
    required Trip trip,
    TripExpense? existingExpense,
    Map<String, String?> photoPaths = const {},
  }) {
    return BlurUtils.showBlurredDialog<TripExpense>(
      context: context,
      child: AddTripExpenseDialog(
        trip: trip,
        existingExpense: existingExpense,
        photoPaths: photoPaths,
      ),
    );
  }

  @override
  State<AddTripExpenseDialog> createState() => _AddTripExpenseDialogState();
}

class _AddTripExpenseDialogState extends State<AddTripExpenseDialog> {
  /// Categories that make sense on a trip, reusing the app's existing icon set.
  /// Key order here is the order they appear in the picker.
  static const List<String> _categories = [
    'travel',
    'food',
    'transport',
    'shopping',
    'entertainment',
    'other',
  ];

  static String _iconForCategory(String category) => switch (category) {
        'travel' => SvgAppIcons.travelIcon,
        'food' => SvgAppIcons.foodIcon,
        'transport' => SvgAppIcons.transportIcon,
        'shopping' => SvgAppIcons.shoppingIcon,
        'entertainment' => SvgAppIcons.entertainmentIcon,
        _ => SvgAppIcons.genericCategoryIcon,
      };

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  /// Per-member inputs, only meaningful for the weighted/exact split modes.
  final Map<String, TextEditingController> _inputControllers = {};

  late SplitMode _mode;
  late String _paidBy;
  late String _category;
  late DateTime _date;
  late Set<String> _participants;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExpense;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
        text: existing == null ? '' : _trimZeros(existing.amount));
    _noteController = TextEditingController(text: existing?.note ?? '');
    _mode = existing?.splitMode ?? SplitMode.equal;
    _paidBy = existing?.paidBy ?? widget.trip.memberNames.first;
    final savedCategory = existing?.category;
    _category = (savedCategory != null && _categories.contains(savedCategory))
        ? savedCategory
        : 'other';
    _date = existing?.date ?? DateTime.now();
    _participants = {...?existing?.shares.keys}..addAll(widget.trip.memberNames);

    if (existing != null) {
      // Seed the weight fields from the saved split so switching back into a
      // weighted mode shows something sensible rather than blanks.
      existing.shares.forEach((member, share) {
        _inputControllers[member] = TextEditingController(
          text: _trimZeros(share),
        );
      });
    }
  }

  static String _trimZeros(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e9) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final controller in _inputControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  Map<String, double> get _weights {
    final weights = <String, double>{};
    for (final member in _participants) {
      final raw = _inputControllers[member]?.text.trim() ?? '';
      weights[member] = double.tryParse(raw) ?? 0.0;
    }
    return weights;
  }

  Map<String, double> get _previewShares =>
      SettlementCalculator.buildShares(
        amount: _amount,
        mode: _mode,
        participants: _participants.toList(),
        inputs: _weights,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currencySymbol =
        context.select<ThemeViewModel, String>((vm) => vm.currencySymbol);
    final preview = _previewShares;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppDimensions.paddingStandard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
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
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingExpense == null
                    ? l10n.addTripExpense
                    : l10n.editItemTitle,
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l10n.tripExpenseTitle),
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.dmSans(
                            fontSize: 15, color: theme.colorScheme.onSurface),
                        decoration: _decoration(l10n.tripExpenseTitle),
                      ),
                      const SizedBox(height: AppDimensions.spacingStandard),
                      _label('${l10n.amount} ($currencySymbol)'),
                      TextField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.dmSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: _decoration('0'),
                      ),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _label(l10n.category),
                      _categoryRow(context),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _label(l10n.paidBy),
                      _payerRow(context),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _label(l10n.splitMode),
                      _modeSelector(context),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _label(l10n.splitBetween),
                      _splitRows(context, preview, currencySymbol),
                      const SizedBox(height: AppDimensions.spacingStandard),
                      _label(l10n.note),
                      TextField(
                        controller: _noteController,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.dmSans(
                            fontSize: 15, color: theme.colorScheme.onSurface),
                        decoration: _decoration(l10n.noNoteProvided),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusRegular),
                    ),
                  ),
                  child: Text(
                    l10n.save,
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _amount > 0 &&
      _participants.isNotEmpty;

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingStandard,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.borderRadiusSmall),
          borderSide: BorderSide.none,
        ),
      );

  Widget _categoryRow(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labels = <String, String>{
      'travel': l10n.tripCatTravel,
      'food': l10n.tripCatFood,
      'transport': l10n.tripCatTransport,
      'shopping': l10n.tripCatShopping,
      'entertainment': l10n.tripCatEntertainment,
      'other': l10n.tripCatOther,
    };

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppDimensions.spacingSmall),
        itemBuilder: (context, index) {
          final key = _categories[index];
          final selected = key == _category;
          return GestureDetector(
            onTap: () => setState(() => _category = key),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusFull),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    _iconForCategory(key),
                    width: AppDimensions.iconSizeSmall,
                    height: AppDimensions.iconSizeSmall,
                    colorFilter: ColorFilter.mode(
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[key]!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _payerRow(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.trip.memberNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.spacingSmall),
        itemBuilder: (context, index) {
          final member = widget.trip.memberNames[index];
          final selected = member == _paidBy;
          final theme = Theme.of(context);
          return GestureDetector(
            onTap: () => setState(() => _paidBy = member),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusFull),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MemberAvatar(
                    name: member,
                    photoPath: widget.photoPaths[member],
                    size: 30,
                  ),
                  const SizedBox(width: AppDimensions.spacingSmall),
                  Text(
                    member,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _modeSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      SplitMode.equal: l10n.splitEqually,
      SplitMode.exact: l10n.splitExact,
      SplitMode.shares: l10n.splitShares,
      SplitMode.percentage: l10n.splitPercentage,
    };
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRegular),
      ),
      child: Row(
        children: [
          for (final mode in SplitMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mode = mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _mode == mode
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusStandard),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[mode]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _mode == mode
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitRows(
    BuildContext context,
    Map<String, double> preview,
    String currencySymbol,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final needsInput = _mode != SplitMode.equal;
    final suffix = switch (_mode) {
      SplitMode.percentage => '%',
      SplitMode.shares => '×',
      _ => currencySymbol,
    };

    return Column(
      children: [
        for (final member in widget.trip.memberNames)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    if (_participants.contains(member)) {
                      if (_participants.length > 1) _participants.remove(member);
                    } else {
                      _participants.add(member);
                    }
                  }),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _participants.contains(member)
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: Icon(
                        _participants.contains(member)
                            ? Icons.check_rounded
                            : Icons.remove_rounded,
                        size: AppDimensions.iconSizeSmall,
                        color: _participants.contains(member)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                MemberAvatar(
                  name: member,
                  photoPath: widget.photoPaths[member],
                  size: 30,
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(
                  child: Text(
                    member,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (needsInput && _participants.contains(member))
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: _inputControllers[member] ??=
                          TextEditingController(),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        suffixText: suffix,
                        suffixStyle: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.45),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusTiny + 6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '$currencySymbol${(preview[member] ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppDimensions.spacingXSmall),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _mode == SplitMode.exact
                ? l10n.splitExactHint
                : l10n.splitPreviewHint,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final existing = widget.existingExpense;
    final expense = TripExpense(
      tripId: widget.trip.key.toString(),
      title: _titleController.text.trim(),
      amount: _amount,
      paidBy: _paidBy,
      date: _date,
      shares: _previewShares,
      category: _category,
      splitModeIndex: _mode.index,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      receiptPaths: existing?.receiptPaths,
    );
    Navigator.of(context).pop(expense);
  }
}
