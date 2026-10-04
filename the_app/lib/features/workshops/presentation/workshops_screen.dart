import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../legal_workstream/models/document.dart';
import '../../legal_workstream/presentation/open_document_viewer.dart';
import '../../legal_workstream/providers/legal_workstream_providers.dart';
import '../models/registration_list.dart';
import '../models/workshop.dart';
import '../providers/workshop_providers.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The base path for the signed-in role ('/admin' or '/consultant').
String _home(UserRole? role) => role == UserRole.administrator ? '/admin' : '/consultant';

/// Onboarding & induction and other BDS workshops (Terms of Reference),
/// with their registration lists for M&E. Admins and consultants only.
class WorkshopsScreen extends ConsumerWidget {
  const WorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshopsAsync = ref.watch(workshopsProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role;

    return AppShell(
      title: 'Workshops',
      globalKey: 'workshops',
      floatingActionButton: TourAnchor(id: TourAnchors.workshopsAdd, child: FloatingActionButton.extended(
        onPressed: () async {
          final id = await showDialog<String>(context: context, builder: (_) => const _NewWorkshopDialog());
          ref.invalidate(workshopsProvider);
          if (id != null && context.mounted) context.go('${_home(role)}/workshops/$id');
        },
        icon: const Icon(Icons.add),
        label: const Text('New workshop'),
      )),
      body: workshopsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load workshops",
          message: 'Check your connection and try again.',
          action: OutlinedButton(onPressed: () => ref.invalidate(workshopsProvider), child: const Text('Try again')),
        ),
        data: (workshops) {
          if (workshops.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No workshops yet',
              message: 'Record each onboarding or induction workshop and who came, then submit '
                  'the registration list to AJW. The Terms of Reference give 5 days after the workshop.',
            );
          }
          final padding = PageBody.paddingFor(context);
          return ListView(
            padding: padding.copyWith(bottom: padding.bottom + 88),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final w in workshops) ...[
                      TourAnchor(id: TourAnchors.workshopsFirst, child: _WorkshopCard(workshop: w, onTap: () => context.go('${_home(role)}/workshops/${w.id}'))),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RegistrationChip extends StatelessWidget {
  const _RegistrationChip({required this.workshop});
  final Workshop workshop;

  @override
  Widget build(BuildContext context) {
    if (workshop.registrationSentAt != null) {
      return const StatusChip('List submitted', tone: StatusTone.success, icon: Icons.check_circle);
    }
    if (workshop.registrationOverdue) {
      return StatusChip('List overdue (was due ${_day(workshop.registrationDue)})', tone: StatusTone.danger, icon: Icons.error_outline);
    }
    return StatusChip('List due ${_day(workshop.registrationDue)}', tone: StatusTone.warning, icon: Icons.schedule);
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.workshop, required this.onTap});
  final Workshop workshop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final w = workshop;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.charcoalSoft),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [_day(w.heldOn), w.kind, if (w.location != null) w.location!, '${w.attendeeCount} registered']
                          .join('  ·  '),
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: Space.sm),
                    _RegistrationChip(workshop: w),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.charcoalSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewWorkshopDialog extends ConsumerStatefulWidget {
  const _NewWorkshopDialog();

  @override
  ConsumerState<_NewWorkshopDialog> createState() => _NewWorkshopDialogState();
}

class _NewWorkshopDialogState extends ConsumerState<_NewWorkshopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController(text: 'Onboarding & induction workshop');
  final _location = TextEditingController();
  String _kind = Workshop.kinds.first;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(workshopRepositoryProvider).create(
            title: _title.text.trim(),
            kind: _kind,
            heldOn: _date,
            location: _location.text,
          );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New workshop'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final k in Workshop.kinds) DropdownMenuItem(value: k, child: Text(k))],
                  onChanged: (k) => setState(() => _kind = k ?? _kind),
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Give the workshop a title' : null,
                ),
                const SizedBox(height: Space.lg),
                InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.edit_calendar_outlined)),
                    child: Text(_day(_date)),
                  ),
                ),
                const SizedBox(height: Space.lg),
                TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location (optional)')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const AjwLoader(dotSize: 6) : const Text('Create')),
      ],
    );
  }
}

/// One workshop: its registration list, export to Sheets for M&E, and
/// marking the list as sent.
class WorkshopDetailScreen extends ConsumerWidget {
  const WorkshopDetailScreen({super.key, required this.workshopId});
  final String workshopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshopAsync = ref.watch(workshopProvider(workshopId));
    final attendeesAsync = ref.watch(workshopAttendeesProvider(workshopId));
    final text = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProfileProvider).value;

    void refresh() {
      ref.invalidate(workshopProvider(workshopId));
      ref.invalidate(workshopAttendeesProvider(workshopId));
      ref.invalidate(workshopsProvider);
    }

    return AppShell(
      title: 'Workshop',
      globalKey: 'workshops',
      body: workshopAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => const EmptyState(isError: true, icon: Icons.cloud_off_outlined, title: "Couldn't load the workshop"),
        data: (w) {
          if (w == null) return const EmptyState(icon: Icons.groups_outlined, title: 'Workshop not found');
          final attendees = attendeesAsync.value ?? const <WorkshopAttendee>[];
          final padding = PageBody.paddingFor(context);
          return ListView(
            padding: padding,
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('${_home(me?.role)}/workshops'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('All workshops'),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(w.title, style: text.headlineMedium),
                    const SizedBox(height: Space.xs),
                    Text([_day(w.heldOn), w.kind, if (w.location != null) w.location!].join('  ·  '), style: text.bodyMedium),
                    const SizedBox(height: Space.md),
                    Align(alignment: Alignment.centerLeft, child: _RegistrationChip(workshop: w)),
                    const SizedBox(height: Space.xl),
                    _Step(
                      number: 1,
                      title: 'Record who came',
                      explanation: 'Add each person who attended, from the sign-in sheet or as they arrive. '
                          'A name is enough; a phone number and business help M&E follow up.',
                      action: FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Add attendee'),
                        onPressed: () async {
                          await showDialog<void>(context: context, builder: (_) => _AddAttendeeDialog(workshopId: w.id));
                          refresh();
                        },
                      ),
                      child: attendees.isEmpty
                          ? Text('No one added yet.', style: text.bodyMedium)
                          : _AttendeeList(attendees: attendees, onChanged: refresh),
                    ),
                    const SizedBox(height: Space.lg),
                    _SubmitStep(workshop: w, attendees: attendees, onSubmitted: refresh),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One numbered step of the workshop flow.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.explanation, this.action, required this.child});

  final int number;
  final String title;
  final String explanation;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.brandRedTint,
                  child: Text('$number', style: text.labelLarge?.copyWith(color: AppColors.brandRedDeep)),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: Space.xs),
                      Text(explanation, style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft)),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: Space.md),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
            const SizedBox(height: Space.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _AttendeeList extends ConsumerWidget {
  const _AttendeeList({required this.attendees, required this.onChanged});
  final List<WorkshopAttendee> attendees;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < attendees.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceSunken,
              child: Text('${i + 1}', style: text.labelMedium),
            ),
            title: Text(attendees[i].fullName),
            subtitle: Text([attendees[i].businessName, attendees[i].phone].whereType<String>().join('  ·  ')),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () async {
                await ref.read(workshopRepositoryProvider).removeAttendee(attendees[i].id);
                onChanged();
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Step 2: save the list as an Excel file in AJW's Documents (Admins).
/// This is the ToR's "registration list to M&E within 5 days".
class _SubmitStep extends ConsumerStatefulWidget {
  const _SubmitStep({required this.workshop, required this.attendees, required this.onSubmitted});
  final Workshop workshop;
  final List<WorkshopAttendee> attendees;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_SubmitStep> createState() => _SubmitStepState();
}

class _SubmitStepState extends ConsumerState<_SubmitStep> {
  bool _busy = false;

  Future<void> _submit() async {
    final me = ref.read(currentUserProfileProvider).value;
    if (me == null) return;
    final list = RegistrationList(widget.workshop, widget.attendees);
    setState(() => _busy = true);
    try {
      await ref.read(documentRepositoryProvider).uploadWorkshopList(
            workshopId: widget.workshop.id,
            uploadedByUserId: me.id,
            fileName: list.fileName,
            bytes: list.toBytes(),
          );
      await ref.read(workshopRepositoryProvider).setRegistrationSent(widget.workshop.id, true);
      ref.invalidate(workshopListsProvider(widget.workshop.id));
      widget.onSubmitted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("List submitted. AJW's admins will find it under Documents.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't submit the list. Check your connection and try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workshop;
    final text = Theme.of(context).textTheme;
    final submitted = ref.watch(workshopListsProvider(w.id)).value ?? const <WorkstreamDocument>[];
    final latest = submitted.isEmpty ? null : submitted.first;
    final due = 'Due ${_day(w.registrationDue)}: the Terms of Reference give 5 days after the workshop.';

    final Widget action = _busy
        ? const AjwLoader(dotSize: 7, semanticsLabel: 'Submitting')
        : latest == null
            ? FilledButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Submit list'),
                onPressed: widget.attendees.isEmpty ? null : _submit,
              )
            : OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Submit an updated list'),
                onPressed: widget.attendees.isEmpty ? null : _submit,
              );

    return _Step(
      number: 2,
      title: 'Submit the list to AJW',
      explanation: 'Saves the list as an Excel file in Documents, where AJW\'s admins (M&E) pick it up. '
          'Nothing is emailed. $due',
      action: action,
      child: latest == null
          ? Text(
              widget.attendees.isEmpty ? 'Add at least one attendee first.' : 'Not submitted yet.',
              style: text.bodyMedium,
            )
          : Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Submitted ${_day(latest.uploadedAt.toLocal())}'
                    '${latest.uploaderName == null ? '' : ' by ${latest.uploaderName}'}'
                    '${submitted.length > 1 ? ' (${submitted.length} versions)' : ''}.',
                    style: text.bodyMedium,
                  ),
                ),
                TextButton(onPressed: () => openDocumentViewer(context, latest), child: const Text('Open')),
              ],
            ),
    );
  }
}

class _AddAttendeeDialog extends ConsumerStatefulWidget {
  const _AddAttendeeDialog({required this.workshopId});
  final String workshopId;

  @override
  ConsumerState<_AddAttendeeDialog> createState() => _AddAttendeeDialogState();
}

class _AddAttendeeDialogState extends ConsumerState<_AddAttendeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _business = TextEditingController();
  int _added = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _business.dispose();
    super.dispose();
  }

  /// Adds and clears the form, so a list can be typed in one go.
  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(workshopRepositoryProvider).addAttendee(
          widget.workshopId,
          fullName: _name.text,
          phone: _phone.text,
          businessName: _business.text,
        );
    setState(() => _added++);
    _name.clear();
    _phone.clear();
    _business.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add attendees'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 340, maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_added > 0) ...[
                Text('$_added added. Keep going, or close when done.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Space.md),
              ],
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _business,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Business (optional)'),
                onFieldSubmitted: (_) => _add(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        FilledButton(onPressed: _add, child: const Text('Add')),
      ],
    );
  }
}
