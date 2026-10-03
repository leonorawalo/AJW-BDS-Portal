import '../../../shared/models/user_profile.dart';
import 'task.dart';

/// The Terms of Reference (ToR) checklists, one per BDS discipline, from
/// AJW Africa's "Terms of Reference: Business Development Services"
/// documents (Legal & HR, Accounting & Tax, Marketing; version
/// September 2022). Refs below are the ToR clause numbers; "target" is the
/// ToR's portfolio-level deliverable.
///
/// Still a static Dart list, not a table: each item becomes a real row in
/// `tasks`, created through the ensure_tor_tasks() database function
/// (migration 20261003100000), which uses [TaskTemplate.key] so an item is
/// never added twice. Changing a key creates a new task; changing a title
/// does not rename existing tasks.
///
/// Titles marked "score" are read by the loan-readiness dashboard
/// (loan_readiness.dart) by exact text. Keep them identical.
enum TorPhase {
  /// ToR: "Create new going concerns ... within 3 months of business
  /// establishment."
  goingConcern,

  /// ToR: businesses "bankable and able to secure services from a bank by
  /// end of 6 months."
  bankable,
}

extension TorPhaseX on TorPhase {
  String get label => switch (this) {
        TorPhase.goingConcern => 'Going concern (first 3 months)',
        TorPhase.bankable => 'Bankable (by month 6)',
      };

  /// Days after enrolment the phase is due.
  int get dueAfterDays => switch (this) {
        TorPhase.goingConcern => 90,
        TorPhase.bankable => 180,
      };
}

class TaskTemplate {
  const TaskTemplate({
    required this.key,
    required this.title,
    required this.description,
    required this.priority,
    required this.phase,
  });

  /// Stable id stored in tasks.tor_key (e.g. "L-2.1.2").
  final String key;
  final String title;
  final String description;
  final TaskPriority priority;
  final TorPhase phase;
  /// The ToR's portfolio-level target for this item ("Target: 90% of
  /// portfolio" in [description]), or null when the ToR sets none.
  int? get targetPercent {
    final m = RegExp(r'Target:[^0-9]*([0-9]+)%').firstMatch(description);
    return m == null ? null : int.parse(m.group(1)!);
  }
}

/// The checklist for a discipline.
List<TaskTemplate> torChecklistFor(ConsultantSpecialization specialization) => switch (specialization) {
      ConsultantSpecialization.legal => standardLegalChecklist,
      ConsultantSpecialization.accounting => standardAccountingChecklist,
      ConsultantSpecialization.marketing => standardMarketingChecklist,
    };

const _gc = TorPhase.goingConcern;
const _bank = TorPhase.bankable;
const _high = TaskPriority.high;
const _med = TaskPriority.medium;
const _low = TaskPriority.low;

/// Legal & Human Resource Business Services ToR.
const List<TaskTemplate> standardLegalChecklist = [
  TaskTemplate(key: 'L-2.1.1', phase: _gc, priority: _high,
      title: 'Advise on business type & registration options',
      description: 'Advise the owner on the different types of business, with the pros and cons of each. ToR 2.1.1.'),
  TaskTemplate(key: 'L-SLA', phase: _gc, priority: _high,
      title: 'Prepare a Service Level Agreement with the business owner',
      description: 'Agree and sign the BDS Service Level Agreement with the owner at onboarding. ToR 3, Program execution.'),
  TaskTemplate(key: 'L-2.1.2', phase: _gc, priority: _high, // score
      title: 'Complete business registration',
      description: 'Register the business on its behalf, following the advice above. ToR 2.1.2. Target: 90% of portfolio.'),
  TaskTemplate(key: 'L-2.1.3', phase: _gc, priority: _high, // score
      title: 'Acquire KRA PIN',
      description: 'Acquire a KRA PIN for both the business and the owner. ToR 2.1.3. Target: 90% of portfolio.'),
  TaskTemplate(key: 'L-2.1.4', phase: _gc, priority: _high, // score
      title: 'Acquire trading licenses',
      description: 'Single business permit plus any National, County and industry-specific licences, including the fire '
          'certificate. ToR 2.1.4. Target: 90% of portfolio.'),
  TaskTemplate(key: 'L-2.1.8', phase: _gc, priority: _med,
      title: 'Review tenancy agreement',
      description: 'Review and advise on the tenancy/lease agreement and sign it off. ToR 2.1.8. Target: 100% of portfolio.'),
  TaskTemplate(key: 'L-2.1.6', phase: _gc, priority: _med,
      title: 'Draft and review contracts',
      description: 'Draft and review agreements with customers, suppliers and employees, and other legal documents. '
          'ToR 2.1.6. Target: review 100%; new contracts for 90% of going concerns.'),
  TaskTemplate(key: 'L-2.1.11', phase: _bank, priority: _high, // score
      title: 'Confirm monthly KRA returns filed',
      description: 'Ensure the monthly KRA tax returns are filed (by the Accountant with the owner). ToR 2.1.11. '
          'Target: 90% of portfolio.'),
  TaskTemplate(key: 'L-TCC', phase: _bank, priority: _high,
      title: 'Obtain KRA Tax Compliance Certificate',
      description: 'Obtain the Tax Compliance Certificate for the going concern, in partnership with the Accountant. '
          'ToR 3, Legal & Regulatory Compliance. Target: 90% of portfolio.'),
  TaskTemplate(key: 'L-2.1.12', phase: _bank, priority: _med,
      title: 'File annual company returns',
      description: 'File the annual returns at the Registrar on behalf of the business. ToR 2.1.12.'),
  TaskTemplate(key: 'L-2.1.5', phase: _bank, priority: _med,
      title: 'Guide AGPO registration',
      description: 'Guide and implement the Access to Government Procurement Opportunities (AGPO) process. ToR 2.1.5. '
          'Target: AGPO certificate for 60% of portfolio.'),
  TaskTemplate(key: 'L-2.1.14', phase: _bank, priority: _med,
      title: 'Arrange business and owner insurance',
      description: 'Risk management: business and personal health insurance or schemes. ToR 2.1.14. '
          'Target: 70% of portfolio.'),
  TaskTemplate(key: 'L-2.1.10', phase: _bank, priority: _med,
      title: 'Confirm KEBS compliance',
      description: 'Ensure compliance with the Kenya Bureau of Standards where it applies. ToR 2.1.10.'),
  TaskTemplate(key: 'L-2.1.9', phase: _bank, priority: _low,
      title: 'Guide on IP protection',
      description: 'Guide on intellectual property rights: patents, trademarks and trade secrets where needed. ToR 2.1.9.'),
  TaskTemplate(key: 'L-2.1.7', phase: _bank, priority: _low,
      title: 'Issue demand letters to overdue debtors',
      description: "Issue demand letters to debtors who have exceeded the business' terms of payment, as needed. "
          'ToR 2.1.7 / 2.1.13. Target: 100% of portfolio.'),
  TaskTemplate(key: 'L-2.1.15', phase: _bank, priority: _low,
      title: 'File beneficiary documents',
      description: "Record keeping: file the beneficiary's documents. ToR 2.1.15."),
  TaskTemplate(key: 'L-2.2.1', phase: _bank, priority: _med,
      title: 'Create organogram and job descriptions',
      description: "Create an organogram for the entity and job descriptions for all staff. ToR 2.2.1. Target: 90% of portfolio."),
  TaskTemplate(key: 'L-2.2.2', phase: _bank, priority: _low,
      title: 'Support staff recruitment',
      description: 'Participate in the staff recruitment process. ToR 2.2.2. Target: 60% of portfolio.'),
  TaskTemplate(key: 'L-2.2.3', phase: _bank, priority: _med,
      title: 'Draft staff contracts',
      description: "Create contracts for the entity's staff. ToR 2.2.3. Target: 90% of portfolio."),
  TaskTemplate(key: 'L-2.2.4', phase: _bank, priority: _low,
      title: 'Build staff induction guidelines',
      description: 'Build and implement staff induction guidelines. ToR 2.2.4.'),
  TaskTemplate(key: 'L-2.2.5', phase: _bank, priority: _low,
      title: 'Draw up a personnel training programme',
      description: 'Draw up a training programme for staff. ToR 2.2.5.'),
  TaskTemplate(key: 'L-2.2.6', phase: _bank, priority: _low,
      title: 'Draft remuneration & disciplinary policy',
      description: 'Establish a remuneration policy and disciplinary guidelines. ToR 2.2.6.'),
  TaskTemplate(key: 'L-2.2.7', phase: _bank, priority: _low,
      title: 'Advise on labour relations',
      description: 'Advise on labour relations under the relevant Government Labour Acts. ToR 2.2.7.'),
];

/// Accounting, Finance, Operations and Procurement ToR. The last four
/// items are the lender evidence behind "bankable by month 6" (KCB's
/// MSME requirements), which the loan-readiness score reads.
const List<TaskTemplate> standardAccountingChecklist = [
  TaskTemplate(key: 'A-BANK', phase: _gc, priority: _high,
      title: 'Open a business bank account',
      description: 'Open a bank account for the business and channel all business proceeds through it. ToR 2.1.6 and '
          'Account opening. Target: 90% of portfolio.'),
  TaskTemplate(key: 'A-2.1.3', phase: _gc, priority: _high, // score
      title: 'Set up financial record-keeping system',
      description: 'Create the physical books of accounts: cash book, petty cash vouchers, payment vouchers, receipt '
          'books and invoice books. ToR 2.1.3. Target: 80% of portfolio.'),
  TaskTemplate(key: 'A-2.1.2', phase: _gc, priority: _med,
      title: 'Coach the owner on book-keeping and savings',
      description: 'Educate the owner on the benefits of book-keeping, accounting, savings and investments. ToR 2.1.2.'),
  TaskTemplate(key: 'A-2.1.5', phase: _gc, priority: _high,
      title: 'Set up budgeting and product costing',
      description: 'Routine budgeting and costing, and separating business expenses from personal ones. ToR 2.1.5.'),
  TaskTemplate(key: 'A-2.1.4.3', phase: _gc, priority: _med,
      title: 'Set up assets and inventory management',
      description: 'An assets and inventory management system for the entity. ToR 2.1.4.3.'),
  TaskTemplate(key: 'A-2.1.4.1', phase: _gc, priority: _med,
      title: 'Prepare cash flow projections',
      description: 'Short, medium and long-term cash flow projections to set the capital requirements. ToR 2.1.4.1.'),
  TaskTemplate(key: 'A-2.1.4.2', phase: _bank, priority: _high,
      title: 'Produce monthly financial reports',
      description: 'Profit and loss, sales, debtors and stock reports, and the balance sheet. ToR 2.1.4.2.'),
  TaskTemplate(key: 'A-RECON', phase: _bank, priority: _med,
      title: 'Prepare monthly bank reconciliations',
      description: 'Reconcile the bank account and resolve reconciling items on time. ToR 3, Accounting Support.'),
  TaskTemplate(key: 'A-KRA', phase: _bank, priority: _high,
      title: 'File monthly KRA returns with the owner',
      description: 'File the monthly KRA returns together with the business owner. ToR 3, Accounting Support.'),
  TaskTemplate(key: 'A-2.1.9', phase: _bank, priority: _med,
      title: 'Manage insurance and statutory deductions',
      description: 'Insurance and statutory deductions handled correctly. ToR 2.1.9.'),
  TaskTemplate(key: 'A-2.1.10', phase: _bank, priority: _med,
      title: 'Set up payments and petty cash management',
      description: 'Customer invoicing, supplier payments (resolving invoice and receipt discrepancies) and petty cash. '
          'ToR 2.1.10.'),
  TaskTemplate(key: 'A-2.1.1', phase: _bank, priority: _med,
      title: 'Track business plan goals',
      description: 'Track implementation of the goals in the business plan written with the Marketer and Lawyer. ToR 2.1.1.'),
  TaskTemplate(key: 'A-2.3', phase: _bank, priority: _med,
      title: 'Plan capacity and production',
      description: 'Capacity planning, production or service systems, product quality control and production '
          'scheduling, with the owner. ToR 2.3. Target: 90% achievement.'),
  TaskTemplate(key: 'A-2.2', phase: _bank, priority: _med,
      title: 'Set up stock control and purchasing',
      description: 'Good-quality inputs, purchase orders, receiving and issuing stock, invoice checks; core and '
          'alternate suppliers and supplier payments. ToR 2.2. Target: 90% achievement.'),
  TaskTemplate(key: 'A-2.1.11', phase: _bank, priority: _low,
      title: 'File accounting and finance documents',
      description: 'Keep all accounting and finance documents filed. ToR 2.1.11.'),
  TaskTemplate(key: 'A-LR-STMT', phase: _bank, priority: _high, // score
      title: 'Compile 6 months of bank statements',
      description: 'Six consistent months of business bank statements: standard lender evidence of cash flow.'),
  TaskTemplate(key: 'A-LR-COLL', phase: _bank, priority: _med, // score
      title: 'Document available collateral for financing',
      description: 'Identify and document assets (land, equipment, vehicles, deposits) usable as loan security.'),
  TaskTemplate(key: 'A-LR-CRB', phase: _bank, priority: _med, // score
      title: 'Check CRB status',
      description: "Confirm the business's and owner's Credit Reference Bureau standing before applying for financing."),
  TaskTemplate(key: 'A-LR-AUDIT', phase: _bank, priority: _low, // score
      title: 'Obtain 3 years of audited accounts',
      description: "Only for loans above KSh 5 million (KCB's secured SME lending). Mark not applicable otherwise."),
];

/// Marketing BDS Consultant ToR: business plans, marketing, public
/// relations and customer service.
const List<TaskTemplate> standardMarketingChecklist = [
  TaskTemplate(key: 'M-2.1.2', phase: _gc, priority: _high,
      title: 'Establish the business information',
      description: 'Business name, contact details (email, phone, postal address) and location; legal and banking '
          'documents with the Legal and Accounting consultants. ToR 2.1.2.'),
  TaskTemplate(key: 'M-2.1.1', phase: _gc, priority: _high,
      title: 'Draft the business plan with the owner',
      description: 'Mission and vision; goals (short, medium, long term); the 4 Ps; marketing assessment with SWOT; '
          'HR and risk (with the Lawyer); financial plan and access to finance (with the Accountant). ToR 2.1.1. '
          'Target: 80% of portfolio.'),
  TaskTemplate(key: 'M-2.1.3', phase: _gc, priority: _med,
      title: 'Create and design the business logo',
      description: 'ToR 2.1.3.'),
  TaskTemplate(key: 'M-2.1.9', phase: _gc, priority: _high,
      title: 'Establish the pricing strategy',
      description: 'ToR 2.1.9.'),
  TaskTemplate(key: 'M-2.1.5', phase: _gc, priority: _med,
      title: 'Set and manage a marketing budget',
      description: 'ToR 2.1.5.'),
  TaskTemplate(key: 'M-2.1.7', phase: _bank, priority: _high,
      title: 'Develop and implement the marketing strategy',
      description: 'Including market trends and forecasts. ToR 2.1.7.'),
  TaskTemplate(key: 'M-2.1.8', phase: _bank, priority: _med,
      title: 'Develop the customer service strategy',
      description: 'Service standards, customer experience and retention, with the owner. ToR 2.1.8.'),
  TaskTemplate(key: 'M-2.1.4', phase: _bank, priority: _med,
      title: 'Develop product differentiation and new lines',
      description: 'ToR 2.1.4.'),
  TaskTemplate(key: 'M-2.1.6', phase: _bank, priority: _med,
      title: 'Grow brand awareness and market share',
      description: 'ToR 2.1.6.'),
  TaskTemplate(key: 'M-2.1.11', phase: _bank, priority: _med,
      title: 'Set up a social media presence',
      description: 'Facebook, LinkedIn, Instagram and other accounts, or a website. ToR 2.1.11.'),
  TaskTemplate(key: 'M-2.1.10', phase: _bank, priority: _med,
      title: 'Pursue tenders and AGPO bids',
      description: 'Guide the business in winning new and existing business, e.g. tenders and government bids '
          'through AGPO (with the Legal consultant). ToR 2.1.10.'),
  TaskTemplate(key: 'M-2.2.3', phase: _bank, priority: _low,
      title: "File the business entity's documents",
      description: 'ToR 2.2.3.'),
];
