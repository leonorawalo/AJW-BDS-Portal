import 'task.dart';

/// Sourced from the AJW Africa Legal & HR Terms of Reference (sections
/// 2.1 Overall Objectives and 2.2 Human Resource). This is deliberately
/// a static Dart list, not a database table — "applying" the checklist
/// just creates real rows in `tasks` via TaskRepository, identical to a
/// Consultant creating each one by hand. No new migration needed.
class TaskTemplate {
  const TaskTemplate({required this.title, required this.description, required this.priority});

  final String title;
  final String description;
  final TaskPriority priority;
}

const List<TaskTemplate> standardLegalChecklist = [
  TaskTemplate(
    title: 'Advise on business type & registration options',
    description: 'Advise the business owner on different business types, pros and cons of each, per ToR 2.1.1.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Complete business registration',
    description: 'Undertake business registration on behalf of the entity, per ToR 2.1.2.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Acquire KRA PIN',
    description: 'Acquire a KRA Personal Identification Number for both the business and the owner, per ToR 2.1.3.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Acquire trading licenses',
    description: 'Acquire relevant National Government, County, and industry-specific trading licenses, including fire certificate, per ToR 2.1.4.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Guide AGPO registration',
    description: 'Guide and implement the process for Access to Government Procurement Opportunities (AGPO), per ToR 2.1.5.',
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Draft and review contracts',
    description: "Draft and review the business' contractual agreements with customers, suppliers, and employees, per ToR 2.1.6.",
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Review tenancy agreement',
    description: 'Review and advise the business on its tenancy agreement, per ToR 2.1.8.',
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Guide on IP protection',
    description: 'Guide the entity on current or emerging intellectual property rights; register trademarks/patents where needed, per ToR 2.1.9.',
    priority: TaskPriority.low,
  ),
  TaskTemplate(
    title: 'Confirm KEBS compliance',
    description: 'Ensure the business complies with Kenya Bureau of Standards requirements where applicable, per ToR 2.1.10.',
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Confirm monthly KRA returns filed',
    description: 'Confirm compliance with monthly KRA tax return filing (in partnership with the Accountant), per ToR 2.1.11.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'File annual company returns',
    description: "Ensure filing of the business' annual company returns at the Registrar, per ToR 2.1.12.",
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Create organogram and job descriptions',
    description: "Create an organogram for the entity and job descriptions for the entity's staff, per ToR 2.2.1.",
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Draft staff contracts',
    description: "Create contracts for the entity's staff, per ToR 2.2.3.",
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Build staff induction guidelines',
    description: 'Build and implement staff induction guidelines, per ToR 2.2.4.',
    priority: TaskPriority.low,
  ),
  TaskTemplate(
    title: 'Draft remuneration & disciplinary policy',
    description: 'Establish a remuneration policy and disciplinary guidelines for the entity, per ToR 2.2.6.',
    priority: TaskPriority.low,
  ),
];

/// Financial/credit-readiness checklist for the Accounting consultant.
/// Unlike [standardLegalChecklist], this isn't sourced from a ToR
/// section number — it exists so the loan-readiness dashboard
/// (lib/features/legal_workstream/models/loan_readiness.dart) can read
/// these facts straight off task completion instead of asking a
/// consultant to re-type them into a separate form. Titles here are
/// matched by exact string in that scoring logic — keep them in sync.
const List<TaskTemplate> standardAccountingChecklist = [
  TaskTemplate(
    title: 'Set up financial record-keeping system',
    description: 'Establish basic bookkeeping (sales, purchases, expenses) so the business has real records, not estimates.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Compile 6 months of bank statements',
    description: 'Gather at least 6 consistent months of business bank statements — standard lender evidence of cash flow.',
    priority: TaskPriority.high,
  ),
  TaskTemplate(
    title: 'Obtain 3 years of audited accounts',
    description: "Required by KCB's secured SME lending for loan amounts above KSh 5 million.",
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Document available collateral for financing',
    description: 'Identify and document any assets (land, equipment, vehicles, cash deposits) usable as loan security.',
    priority: TaskPriority.medium,
  ),
  TaskTemplate(
    title: 'Check CRB status',
    description: "Confirm the business/owner's Credit Reference Bureau standing before applying for financing.",
    priority: TaskPriority.medium,
  ),
];