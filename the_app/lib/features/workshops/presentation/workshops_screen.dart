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
import '../../google_exports/models/sheet_tab.dart';
import '../../google_exports/presentation/google_export_flow.dart';
import '../../google_exports/providers/google_export_providers.dart';
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
              message: 'Record each onboarding & induction workshop and its registration list. '
                  'The Terms of Reference ask for the list to reach M&E within 5 days.',
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
      return const StatusChip('List sent to M&E', tone: StatusTone.success, icon: Icons.check_circle);
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
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RegistrationChip(workshop: w),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Registration list to Sheets'),
                          onPressed: attendees.isEmpty
                              ? null
                              : () => runGoogleExport(
                                    context,
                                    ref,
                                    appName: 'Google Sheets',
                                    create: () => ref.read(googleExportRepositoryProvider).exportSheet(
                                          title: 'Registration list: ${w.title}, ${_day(w.heldOn)}',
                                          tabs: [
                                            SheetTab(name: 'Registration', rows: [
                                              ['#', 'Full name', 'Phone', 'Business', 'Workshop', 'Date', 'Location'],
                                              for (var i = 0; i < attendees.length; i++)
                                                [
                                                  i + 1,
                                                  attendees[i].fullName,
                                                  attendees[i].phone ?? '',
                                                  attendees[i].businessName ?? '',
                                                  w.title,
                                                  _day(w.heldOn),
                                                  w.location ?? '',
                                                ],
                                            ]),
                                          ],
                                        ),
                                  ),
                        ),
                        if (w.registrationSentAt == null)
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.outgoing_mail),
                            label: const Text('Mark list sent to M&E'),
                            onPressed: () async {
                              await ref.read(workshopRepositoryProvider).setRegistrationSent(w.id, true);
                              refresh();
                            },
                          )
                        else
                          TextButton(
                            onPressed: () async {
                              await ref.read(workshopRepositoryProvider).setRegistrationSent(w.id, false);
                              refresh();
                            },
                            child: const Text('Undo "sent"'),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    Row(
                      children: [
                        Expanded(child: Text('Registration list (${attendees.length})', style: text.titleLarge)),
                        FilledButton.icon(
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Add attendee'),
                          onPressed: () async {
                            await showDialog<void>(context: context, builder: (_) => _AddAttendeeDialog(workshopId: w.id));
                            refresh();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    if (attendees.isEmpty)
                      Text('No one registered yet.', style: text.bodyMedium)
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < attendees.length; i++) ...[
                              if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                              ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.surfaceSunken,
                                  child: Text('${i + 1}', style: text.labelMedium),
                                ),
                                title: Text(attendees[i].fullName),
                                subtitle: Text(
                                  [attendees[i].businessName, attendees[i].phone].whereType<String>().join('  ·  '),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.close),
                                  onPressed: () async {
                                    await ref.read(workshopRepositoryProvider).removeAttendee(attendees[i].id);
                                    refresh();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
