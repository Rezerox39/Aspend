import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/const/app_dimensions.dart';
import '../core/models/trip.dart';
import '../core/utils/blur_utils.dart';
import '../core/view_models/person_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import 'member_avatar.dart';

/// Create or edit a trip: name, destination, date range, and members picked
/// from the People tab (a trip never invents its own people).
class AddTripDialog extends StatefulWidget {
  const AddTripDialog({super.key, this.existingTrip});

  final Trip? existingTrip;

  static Future<Trip?> show(BuildContext context, {Trip? existingTrip}) {
    return BlurUtils.showBlurredDialog<Trip>(
      context: context,
      child: AddTripDialog(existingTrip: existingTrip),
    );
  }

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;

  late DateTime _startDate;
  DateTime? _endDate;
  late Set<String> _selected;

  bool get _isEditing => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTrip;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _destinationController =
        TextEditingController(text: existing?.destination ?? '');
    _startDate = existing?.startDate ?? DateTime.now();
    _endDate = existing?.endDate;
    _selected = {...?existing?.memberNames};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final people = context.watch<PersonViewModel>().people
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppDimensions.paddingStandard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
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
                _isEditing ? l10n.editTrip : l10n.newTrip,
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
                      _fieldLabel(l10n.tripName),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: _inputDecoration(l10n.tripName),
                      ),
                      const SizedBox(height: AppDimensions.spacingStandard),
                      _fieldLabel(l10n.tripDestination),
                      TextField(
                        controller: _destinationController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: _inputDecoration(l10n.tripDestination),
                      ),
                      const SizedBox(height: AppDimensions.spacingStandard),
                      _fieldLabel(l10n.tripDates),
                      Row(
                        children: [
                          Expanded(
                            child: _dateButton(
                              context,
                              label: l10n.date,
                              value: _startDate,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingMedium),
                          Expanded(
                            child: _dateButton(
                              context,
                              label: l10n.settle,
                              value: _endDate,
                              allowClear: true,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _fieldLabel(l10n.tripMembers),
                      if (people.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.addPeopleEmptyDesc,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: AppDimensions.spacingSmall,
                          runSpacing: AppDimensions.spacingSmall,
                          children: [
                            for (final person in people)
                              _memberChip(context, person.name,
                                  person.photoPath),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.length < 2 || _nameController.text.trim().isEmpty
                      ? null
                      : _submit,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
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

  Widget _dateButton(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    bool allowClear = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(AppDimensions.borderRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingStandard,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius:
              BorderRadius.circular(AppDimensions.borderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: AppDimensions.iconSizeSmall,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: AppDimensions.spacingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  Text(
                    value == null ? '—' : DateFormat('MMM d, yyyy').format(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (allowClear && value != null)
              GestureDetector(
                onTap: () => setState(() => _endDate = null),
                child: Icon(Icons.close_rounded,
                    size: AppDimensions.iconSizeSmall,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memberChip(BuildContext context, String name, String? photoPath) {
    final theme = Theme.of(context);
    final selected = _selected.contains(name);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(name);
        } else {
          _selected.add(name);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
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
            MemberAvatar(name: name, photoPath: photoPath, size: 26),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              name,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        // Keep the range coherent if the end now falls before the start.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    final existing = widget.existingTrip;
    final trip = Trip(
      name: _nameController.text.trim(),
      destination: _destinationController.text.trim().isEmpty
          ? null
          : _destinationController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      memberNames: _selected.toList(),
      notes: existing?.notes,
      coverPhotoPath: existing?.coverPhotoPath,
      isArchived: existing?.isArchived ?? false,
      createdAt: existing?.createdAt,
    );
    Navigator.of(context).pop(trip);
  }
}
