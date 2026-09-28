import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/const/app_currencies.dart';
import '../core/const/app_dimensions.dart';
import '../core/models/trip.dart';
import '../core/models/trip_member.dart';
import '../core/utils/blur_utils.dart';
import '../core/view_models/person_view_model.dart';
import '../l10n/generated/app_localizations.dart';
import 'member_avatar.dart';

/// Create or edit a trip: name, destination, date range, the currency the trip
/// is settled in, and the people sharing it.
///
/// Members belong to the trip. People already in the app are offered as a
/// one-tap shortcut, but nothing here requires them — a trip can add anybody.
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
  late List<TripMember> _members;
  late String _baseCurrency;

  final TextEditingController _memberController = TextEditingController();
  String? _duplicateWarning;

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
    _members = [...?existing?.members];
    _baseCurrency = existing?.baseCurrency ?? 'INR';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Offered as a shortcut only. A trip does not depend on the People tab.
    final people = [...context.watch<PersonViewModel>().people]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final unadded = people
        .where((p) => _members.every((m) => !TripMember.namesMatch(m.name, p.name)))
        .toList();

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
                      const SizedBox(height: AppDimensions.spacingStandard),
                      _fieldLabel(l10n.tripBaseCurrency),
                      _currencyPicker(context),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      _fieldLabel(l10n.tripMembers),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _memberController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => _checkDuplicate(),
                              onSubmitted: (_) => _addMember(),
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: _inputDecoration(
                                l10n.tripMemberNameHint,
                              ).copyWith(
                                errorText: _duplicateWarning == null
                                    ? null
                                    : l10n.tripMemberDuplicate,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSmall),
                          IconButton.filledTonal(
                            onPressed: _addMember,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            tooltip: l10n.add,
                          ),
                        ],
                      ),
                      if (unadded.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spacingSmall),
                        Wrap(
                          spacing: AppDimensions.spacingSmall,
                          runSpacing: AppDimensions.spacingSmall,
                          children: [
                            for (final person in unadded)
                              _suggestionChip(context, person.name),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppDimensions.spacingSmall),
                      if (_members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.tripMembersEmpty,
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
                            for (final member in _members)
                              _memberChip(context, member),
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
                  onPressed:
                      _members.length < 2 || _nameController.text.trim().isEmpty
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

  /// Warns when the typed name is already on the trip, so somebody cannot
  /// quietly add a second "Rahul" by adding a little whitespace or a capital.
  void _checkDuplicate() {
    final typed = _memberController.text.trim();
    final duplicate =
        typed.isNotEmpty && _members.any((m) => TripMember.namesMatch(m.name, typed));
    final warning = duplicate ? typed : null;
    if (warning != _duplicateWarning) {
      setState(() => _duplicateWarning = warning);
    }
  }

  void _addMember([String? name]) {
    final candidate = (name ?? _memberController.text).trim();
    if (candidate.isEmpty) return;
    final existing = _members.where((m) => TripMember.namesMatch(m.name, candidate));
    if (existing.isNotEmpty) {
      // Already here. Select it rather than adding a near-duplicate.
      setState(() {
        _duplicateWarning = null;
        _memberController.clear();
      });
      return;
    }
    setState(() {
      _members = [..._members, TripMember(id: Trip.memberIdFor(candidate), name: candidate)];
      _memberController.clear();
      _duplicateWarning = null;
    });
  }

  Widget _suggestionChip(BuildContext context, String name) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: () => _addMember(name),
      avatar: MemberAvatar(name: name, size: 22),
      label: Text(
        name,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: theme.colorScheme.onSurface,
        ),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
      ),
    );
  }

  Widget _memberChip(BuildContext context, TripMember member) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _editMemberDetails(context, member),
      onLongPress: () => _confirmRemoveMember(context, member),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(name: member.displayName, size: 26),
            const SizedBox(width: AppDimensions.spacingSmall),
            Text(
              member.displayName,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _confirmRemoveMember(context, member),
              child: Icon(
                Icons.close_rounded,
                size: AppDimensions.iconSizeSmall,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optional contact details, and a label for two members who share a name.
  Future<void> _editMemberDetails(BuildContext context, TripMember member) async {
    final l10n = AppLocalizations.of(context)!;
    final labelController = TextEditingController(text: member.label);
    final phoneController = TextEditingController(text: member.phone);
    final emailController = TextEditingController(text: member.email);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(member.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(labelText: l10n.tripMemberLabel),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.tripMemberPhone),
              ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.tripMemberEmail),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() {
        member.label = _blankToNull(labelController.text);
        member.phone = _blankToNull(phoneController.text);
        member.email = _blankToNull(emailController.text);
      });
    }
    labelController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  Future<void> _confirmRemoveMember(BuildContext context, TripMember member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(member.name),
        content: Text(l10n.tripMemberRemoveDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _members = _members.where((m) => m.id != member.id).toList());
    }
  }

  static String? _blankToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Widget _currencyPicker(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingStandard,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _baseCurrency,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRegular),
          items: [
            for (final currency in AppCurrencies.all)
              DropdownMenuItem<String>(
                value: currency.code,
                child: Text(
                  '${currency.flag}  ${currency.code} — ${currency.name}',
                  style: GoogleFonts.dmSans(fontSize: 14),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _baseCurrency = value);
          },
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
      memberNames: _members.map((m) => m.name).toList(),
      members: _members,
      baseCurrency: _baseCurrency,
      notes: existing?.notes,
      coverPhotoPath: existing?.coverPhotoPath,
      isArchived: existing?.isArchived ?? false,
      createdAt: existing?.createdAt,
    );
    Navigator.of(context).pop(trip);
  }
}
