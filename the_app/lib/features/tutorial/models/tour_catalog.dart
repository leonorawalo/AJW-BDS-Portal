import '../../../shared/models/user_profile.dart';
import 'tour.dart';

/// Every guided tour's text, per role and place. Static data (like the ToR
/// checklists), not a table: changing a bubble is a code change.
///
/// Places: 'welcome' (first time in the app), 'enterprise' (first time
/// inside any enterprise), a role page ('enterprises', 'programme',
/// 'workshops', 'users', 'audit', 'portfolio'), an enterprise section
/// ('section.tasks', ...), 'task' (task detail) and 'assign' (assign
/// consultants). Anchor ids are in [TourAnchors].
///
/// Style: a short title, then 2-3 short, plain sentences. Say what the
/// spot does and why it matters; no jargon beyond the programme's own
/// words (ToR, going concern, bankable).
Tour? tourFor(UserRole role, String place) {
  final r = switch (role) {
    UserRole.administrator => 'admin',
    UserRole.consultant => 'consultant',
    UserRole.enterpriseOwner => 'owner',
  };
  final steps = _tours['$r.$place'];
  return steps == null ? null : Tour('$r.$place', steps);
}

/// Anchor ids shared by the catalog and the widgets that mark the spots.
abstract final class TourAnchors {
  // Shell
  static const hamburger = 'shell.menu';
  static const sideMenu = 'shell.sidemenu';
  static const badge = 'shell.badge';
  static const switcher = 'shell.switcher';
  static const help = 'shell.help';
  static String page(String key) => 'menu.$key';
  static String section(String key) => 'section.$key';

  // Top-bar actions
  static const email = 'action.email';
  static const export = 'action.export';
  static const assign = 'action.assign';
  static const audit = 'action.audit';
  static const portfolioExport = 'action.portfolioExport';

  // Role pages
  static const enterprisesAdd = 'enterprises.add';
  static const enterprisesFirst = 'enterprises.first';
  static const kpis = 'portfolio.kpis';
  static const monthlyReport = 'portfolio.report';
  static const usersInvite = 'users.invite';
  static const usersSearch = 'users.search';
  static const usersFirst = 'users.first';
  static const auditFilters = 'audit.filters';
  static const workshopsAdd = 'workshops.add';
  static const workshopsFirst = 'workshops.first';

  // Enterprise sections
  static const clock = 'dashboard.clock';
  static const scores = 'dashboard.scores';
  static const drivers = 'dashboard.drivers';
  static const facts = 'dashboard.facts';
  static const tasksProgress = 'tasks.progress';
  static const tasksFirst = 'tasks.first';
  static const tasksAdd = 'tasks.add';
  static const visitsMonth = 'visits.month';
  static const visitsFirst = 'visits.first';
  static const visitsAdd = 'visits.add';
  static const recsAdd = 'recs.add';
  static const recsFirst = 'recs.first';
  static const documentsAdd = 'documents.add';
  static const documentsFilters = 'documents.filters';
  static const filesAdd = 'files.add';
  static const filesFirst = 'files.first';
  static const filesFilters = 'files.filters';
  static const sessionsGoogle = 'sessions.google';
  static const sessionsAdd = 'sessions.add';
  static const sessionsFirst = 'sessions.first';
  static const detailsOwner = 'details.owner';
  static const detailsConsultants = 'details.consultants';

  // Task detail, assign consultants
  static const taskStatus = 'task.status';
  static const taskDocuments = 'task.documents';
  static const taskComments = 'task.comments';
  static const assignFirst = 'assign.first';
}

typedef _A = TourAnchors;

// ---------------------------------------------------------------- shared
const _redDots = TourStep(
  title: 'Red dots',
  body: 'A small red dot means something new is waiting for you there. '
      'It clears as soon as you open it.',
  anchors: [_A.sideMenu, _A.hamburger],
);
const _help = TourStep(
  title: 'Tips any time',
  body: 'Choose "Show tips for this page" in the menu at any time. The tips '
      "for the page you're on play again.",
  anchors: [_A.help, _A.hamburger],
);
const _you = TourStep(
  title: "That's you",
  body: 'Your name and role. If your role looks wrong, ask an AJW administrator.',
  anchors: [_A.badge],
);
const _email = TourStep(
  title: 'Email',
  body: 'Write to the people on this enterprise from your own Gmail, so replies '
      'come back to you. You can also find past emails with them in Gmail.',
  anchors: [_A.email],
);
const _export = TourStep(
  title: 'Reports',
  body: 'Download the loan-readiness report as a PDF. You can also create it in '
      'Google Docs, export the data to Sheets, or make a progress deck in Slides.',
  anchors: [_A.export],
);
const _switcher = TourStep(
  title: 'Switch enterprise',
  body: 'Tap the name to jump to another enterprise. You stay on the same section.',
  anchors: [_A.switcher],
);
const _clock = TourStep(
  title: 'Programme clock',
  body: 'Which month of the 12-month programme this is. Going concern is due by '
      'month 3 and bankable by month 6; it turns red if one is overdue.',
  anchors: [_A.clock],
);
const _drivers = TourStep(
  title: "What's driving the score",
  body: 'Each line names the task behind it. When that task is completed in '
      'Tasks, the line turns green and the score goes up.',
  anchors: [_A.drivers],
);
const _monthlyReport = TourStep(
  title: 'Monthly report',
  body: "Creates the BDS Status Report, Activity Report and next month's Workplan "
      'as one Google Doc. They are due by the 3rd, so it starts on last month.',
  anchors: [_A.monthlyReport],
);
const _workshops = [
  TourStep(
    title: 'New workshop',
    body: 'Record an onboarding, induction or BDS workshop. Then add attendees '
        'one after another as they register.',
    anchors: [_A.workshopsAdd],
  ),
  TourStep(
    title: 'Registration lists',
    body: 'Each list must reach M&E within 5 days. Open a workshop to export its '
        'list to Google Sheets and mark it sent; late lists turn red.',
    anchors: [_A.workshopsFirst],
  ),
];
const _documents = [
  TourStep(
    title: 'Upload',
    body: 'Add a file and choose its category. Everyone working on this '
        'enterprise can open it here.',
    anchors: [_A.documentsAdd],
  ),
  TourStep(
    title: 'Find a document',
    body: 'Search by name, or filter by category, who uploaded it and date. '
        'Tap a document to view it.',
    anchors: [_A.documentsFilters],
  ),
];
const _files = [
  TourStep(
    title: 'New Google file',
    body: 'Create a Doc, Sheet or Slides in your own Google Drive. It is shared, '
        'as editor, with the owner and the assigned consultants.',
    anchors: [_A.filesAdd],
  ),
  TourStep(
    title: 'File options',
    body: "Use a file's menu to open it in Google or download it as a PDF. If "
        'someone joins the team later, share it with them from there too.',
    anchors: [_A.filesFirst],
  ),
  TourStep(
    title: 'Find a file',
    body: 'Search by file name. Filter by type, who made it, or when.',
    anchors: [_A.filesFilters],
  ),
];
const _sessions = [
  TourStep(
    title: 'Connect Google once',
    body: 'Sessions use your own Google Calendar and Meet. Connect your Google '
        'account here once; the same connection sends email and makes Google files.',
    anchors: [_A.sessionsGoogle],
  ),
  TourStep(
    title: 'Schedule a session',
    body: 'Choose who, when and a title. The portal checks they are free, creates '
        'the meeting with a Meet link and sends the invitations.',
    anchors: [_A.sessionsAdd],
  ),
  TourStep(
    title: 'Join or cancel',
    body: 'Join the Meet or email the participants from here. Cancelling removes '
        "the meeting from everyone's calendar.",
    anchors: [_A.sessionsFirst],
  ),
];

final Map<String, List<TourStep>> _tours = {
  // ------------------------------------------------------------ welcome
  'admin.welcome': const [
    TourStep(
      title: 'Welcome to the BAGS Portal',
      body: 'This is where AJW runs the BAGS programme: every enterprise, '
          'consultant and owner in one place. A few quick tips follow; skip them any time.',
    ),
    TourStep(
      title: 'Your menu',
      body: 'Enterprises, Programme, Workshops, Users and the Audit log are here. '
          "When you open an enterprise, its sections appear underneath.",
      anchors: [_A.sideMenu, _A.hamburger],
    ),
    _you,
    _redDots,
    _help,
  ],
  'consultant.welcome': const [
    TourStep(
      title: 'Welcome to the BAGS Portal',
      body: 'Your workspace for the enterprises you advise: tasks, visits, '
          'sessions and reports in one place. A few quick tips follow; skip them any time.',
    ),
    TourStep(
      title: 'Your menu',
      body: 'My portfolio lists your enterprises, and Workshops holds onboarding '
          "and BDS workshops. When you open an enterprise, its sections appear underneath.",
      anchors: [_A.sideMenu, _A.hamburger],
    ),
    _you,
    _redDots,
    _help,
  ],
  'owner.welcome': const [
    TourStep(
      title: 'Welcome to the BAGS Portal',
      body: "Your business's space in AJW's BAGS programme. Follow your progress "
          'toward a bank loan and work with your consultants here.',
    ),
    TourStep(
      title: 'Your menu',
      body: 'Each section covers one part of your progress. The Dashboard sums it '
          'up, and the other sections hold the details.',
      anchors: [_A.sideMenu, _A.hamburger],
    ),
    _you,
    _redDots,
    _help,
  ],

  // ----------------------------------------------------- inside an enterprise
  'admin.enterprise': const [
    _switcher,
    TourStep(
      title: 'Assign consultants',
      body: "Choose this enterprise's Legal, Accounting and Marketing consultants. "
          'Their ToR tasks are added automatically.',
      anchors: [_A.assign],
    ),
    TourStep(
      title: 'History',
      body: 'Every change made to this enterprise, from the audit log. Use it to '
          'see who changed what, and when.',
      anchors: [_A.audit],
    ),
    _email,
    _export,
  ],
  'consultant.enterprise': const [_switcher, _email, _export],
  'owner.enterprise': const [_email, _export],

  // --------------------------------------------------------------- admin pages
  'admin.enterprises': const [
    TourStep(
      title: 'Enterprise cards',
      body: 'Each card shows the business, its owner and status, and the programme '
          'clock underneath. Tap a card to open it.',
      anchors: [_A.enterprisesFirst],
    ),
    TourStep(
      title: 'Register an enterprise',
      body: 'Add a new business to the programme. Then, inside it, assign its '
          'consultants and invite its owner.',
      anchors: [_A.enterprisesAdd],
    ),
    TourStep(
      title: 'Portfolio to Sheets',
      body: 'Exports one row per enterprise to Google Sheets. Each row has the '
          'scores, consultants, open tasks and last activity.',
      anchors: [_A.portfolioExport],
    ),
  ],
  'admin.programme': const [
    TourStep(
      title: 'Programme measures',
      body: "The Terms of Reference targets for the whole portfolio, such as the "
          '30-client minimum and going concern within 3 months. Each bar shows progress to its target.',
      anchors: [_A.kpis],
    ),
    _monthlyReport,
  ],
  'admin.workshops': _workshops,
  'admin.users': const [
    TourStep(
      title: 'Invite people',
      body: "Invite administrators, consultants and owners by email. Check the role "
          "and specialization before sending: a consultant's tasks follow their specialization.",
      anchors: [_A.usersInvite],
    ),
    TourStep(
      title: 'Find someone',
      body: 'Search by name or email. The list narrows as you type.',
      anchors: [_A.usersSearch],
    ),
    TourStep(
      title: 'Change or suspend',
      body: "Use a person's menu to change their role or specialization, or suspend "
          'their access. A specialization can only change once their assignments are ended.',
      anchors: [_A.usersFirst],
    ),
  ],
  'admin.audit': const [
    TourStep(
      title: 'Filter the log',
      body: 'Narrow the log by enterprise, person or dates. Key changes are recorded '
          "automatically and can't be edited.",
      anchors: [_A.auditFilters],
    ),
  ],

  // ---------------------------------------------------------- consultant pages
  'consultant.portfolio': const [
    TourStep(
      title: 'Your ToR measures',
      body: 'How your portfolio is doing against the Terms of Reference targets. '
          'It covers going concern within 3 months, visits this month and more.',
      anchors: [_A.kpis],
    ),
    _monthlyReport,
    TourStep(
      title: 'Your enterprises',
      body: 'One card per enterprise you advise, with its programme clock. '
          'Tap a card to work on it.',
      anchors: [_A.enterprisesFirst],
    ),
  ],
  'consultant.workshops': _workshops,

  // ------------------------------------------------------------- dashboard
  'admin.section.dashboard': const [
    _clock,
    TourStep(
      title: 'Loan readiness',
      body: 'Business Health, Credit Readiness and the KCB checklist are worked out '
          'from completed ToR tasks. Nobody fills them in by hand.',
      anchors: [_A.scores],
    ),
    _drivers,
    TourStep(
      title: 'Business facts',
      body: "Turnover, start date and loan purpose can't come from tasks, so they "
          'are entered here. Update them whenever better figures come in.',
      anchors: [_A.facts],
    ),
  ],
  'consultant.section.dashboard': const [
    _clock,
    TourStep(
      title: 'Loan readiness',
      body: 'Business Health, Credit Readiness and the KCB checklist rise as ToR '
          'tasks are completed. Nobody fills them in by hand.',
      anchors: [_A.scores],
    ),
    _drivers,
    TourStep(
      title: 'Business facts',
      body: "Turnover, start date and loan purpose can't come from tasks, so enter "
          'them here. Update them whenever you learn better figures.',
      anchors: [_A.facts],
    ),
  ],
  'owner.section.dashboard': const [
    TourStep(
      title: 'Your loan readiness',
      body: 'These scores rise as your ToR tasks are completed. They show how close '
          'your business is to being ready for a bank loan.',
      anchors: [_A.scores],
    ),
    _clock,
    TourStep(
      title: "What's driving the score",
      body: 'Each line names the task behind it. As that task is completed, the line '
          'turns green.',
      anchors: [_A.drivers],
    ),
    TourStep(
      title: 'Your business facts',
      body: 'Your consultant keeps these figures up to date. Tell them when something changes.',
      anchors: [_A.facts],
    ),
  ],

  // ----------------------------------------------------------------- tasks
  'admin.section.tasks': const [
    TourStep(
      title: 'ToR tasks',
      body: "Each consultant's Terms of Reference tasks appear here automatically, "
          'grouped by phase. The bar shows how many are done.',
      anchors: [_A.tasksProgress],
    ),
    TourStep(
      title: 'Task details',
      body: 'Tap a task to read its comments and documents and to comment. Only the '
          "consultant and the owner change a task's status.",
      anchors: [_A.tasksFirst],
    ),
    TourStep(
      title: 'Add a task',
      body: "Add a custom task for anything the ToR checklist doesn't cover. It "
          'appears under Other tasks.',
      anchors: [_A.tasksAdd],
    ),
  ],
  'consultant.section.tasks': const [
    TourStep(
      title: 'Your ToR tasks',
      body: 'The Terms of Reference tasks for your specialization appear here '
          'automatically, grouped by phase. The bar shows how many are done.',
      anchors: [_A.tasksProgress],
    ),
    TourStep(
      title: 'Open a task',
      body: 'Tap a task to change its status, comment or attach documents. '
          'Completed tasks raise the loan-readiness scores.',
      anchors: [_A.tasksFirst],
    ),
    TourStep(
      title: 'Add your own',
      body: 'Add a custom task for anything outside the ToR checklist. It appears '
          'under Other tasks.',
      anchors: [_A.tasksAdd],
    ),
  ],
  'owner.section.tasks': const [
    TourStep(
      title: 'Your tasks',
      body: 'The steps your consultants are working through with you, grouped by '
          'phase. The bar shows how many are done.',
      anchors: [_A.tasksProgress],
    ),
    TourStep(
      title: 'Open a task',
      body: 'Tap a task to update its status or attach a document. Use the '
          'comments to ask your consultant a question.',
      anchors: [_A.tasksFirst],
    ),
    TourStep(
      title: 'Add a task',
      body: "Add something you'd like your consultants to track with you. It "
          'appears under Other tasks.',
      anchors: [_A.tasksAdd],
    ),
  ],

  // ---------------------------------------------------------------- visits
  'admin.section.visits': const [
    TourStep(
      title: 'Visits this month',
      body: 'The ToR expects 2 visits a month per discipline. This shows how many '
          'each consultant has logged.',
      anchors: [_A.visitsMonth],
    ),
    TourStep(
      title: 'Visit log',
      body: 'Every visit or call, with what happened and the next steps. Visits '
          'logged more than 2 days late are flagged.',
      anchors: [_A.visitsFirst],
    ),
  ],
  'consultant.section.visits': const [
    TourStep(
      title: 'Log a visit',
      body: 'Record each visit or call: what happened and the next steps. Log it '
          'within 2 days, or it is flagged as late.',
      anchors: [_A.visitsAdd],
    ),
    TourStep(
      title: 'Visits this month',
      body: 'The ToR expects 2 visits a month per discipline. This keeps count for you.',
      anchors: [_A.visitsMonth],
    ),
  ],
  'owner.section.visits': const [
    TourStep(
      title: 'Visits to your business',
      body: 'Every visit or call your consultants log appears here. Each one shows '
          'what was agreed and the next steps.',
      anchors: [_A.visitsFirst, _A.visitsMonth],
    ),
  ],

  // ------------------------------------------------------- recommendations
  'admin.section.recommendations': const [
    TourStep(
      title: 'Add a recommendation',
      body: 'Write advice for the owner and set its priority. The owner sees it straight away.',
      anchors: [_A.recsAdd],
    ),
    TourStep(
      title: 'Mark it actioned',
      body: 'When the owner has acted on a recommendation, mark it actioned. It '
          'moves to Done.',
      anchors: [_A.recsFirst],
    ),
  ],
  'consultant.section.recommendations': const [
    TourStep(
      title: 'Add a recommendation',
      body: 'Write advice for the owner and set its priority. The owner sees it straight away.',
      anchors: [_A.recsAdd],
    ),
    TourStep(
      title: 'Mark it actioned',
      body: 'When the owner has acted on a recommendation, mark it actioned. It '
          'moves to Done.',
      anchors: [_A.recsFirst],
    ),
  ],
  'owner.section.recommendations': const [
    TourStep(
      title: 'Advice for your business',
      body: "Your consultants' recommendations, each with its priority and whether "
          "it's been actioned. Ask them about anything unclear.",
      anchors: [_A.recsFirst, 'section.recommendations'],
    ),
  ],

  // ------------------------------------------------- documents, files, sessions
  'admin.section.documents': _documents,
  'consultant.section.documents': _documents,
  'owner.section.documents': _documents,
  'admin.section.files': _files,
  'consultant.section.files': _files,
  'owner.section.files': _files,
  'admin.section.sessions': _sessions,
  'consultant.section.sessions': _sessions,
  'owner.section.sessions': _sessions,

  // ------------------------------------------------------- details (admin)
  'admin.section.details': const [
    TourStep(
      title: "Owner's login",
      body: "Link this enterprise to its owner's portal account. If they don't have "
          'one yet, invite them by email so they can follow their progress.',
      anchors: [_A.detailsOwner],
    ),
    TourStep(
      title: 'Consultants',
      body: 'Who is assigned for Legal, Accounting and Marketing. Use "Assign '
          'consultant" at the top to change them.',
      anchors: [_A.detailsConsultants],
    ),
  ],

  // ------------------------------------------------------------ task detail
  'admin.task': const [
    TourStep(
      title: 'Status',
      body: "Only the consultant and the owner change a task's status. You can follow it here.",
      anchors: [_A.taskStatus],
    ),
    TourStep(
      title: 'Documents',
      body: 'Files attached as evidence for this task, such as a certificate or a '
          'statement. Tap one to view it.',
      anchors: [_A.taskDocuments],
    ),
    TourStep(
      title: 'Comments',
      body: 'Questions and updates about this task. Add yours at the bottom.',
      anchors: [_A.taskComments],
    ),
  ],
  'consultant.task': const [
    TourStep(
      title: 'Status',
      body: 'Set where this task stands. Completed tasks count toward the '
          'loan-readiness scores straight away.',
      anchors: [_A.taskStatus],
    ),
    TourStep(
      title: 'Evidence',
      body: 'Attach documents that prove the work, such as a certificate or a '
          'statement. They also appear under Documents.',
      anchors: [_A.taskDocuments],
    ),
    TourStep(
      title: 'Comments',
      body: 'Ask questions and post updates here. The owner sees a red dot when you comment.',
      anchors: [_A.taskComments],
    ),
  ],
  'owner.task': const [
    TourStep(
      title: 'Status',
      body: 'Update where this task stands. Completed tasks raise your loan-readiness '
          'scores straight away.',
      anchors: [_A.taskStatus],
    ),
    TourStep(
      title: 'Evidence',
      body: 'Attach documents for this task, such as a certificate or a statement. '
          'They also appear under Documents.',
      anchors: [_A.taskDocuments],
    ),
    TourStep(
      title: 'Comments',
      body: 'Ask your consultant a question or post an update here. They see a red '
          'dot when you comment.',
      anchors: [_A.taskComments],
    ),
  ],

  // ----------------------------------------------------- assign consultants
  'admin.assign': const [
    TourStep(
      title: 'One consultant per discipline',
      body: 'Each enterprise gets a Legal, an Accounting and a Marketing consultant. '
          'Pick one for each; their ToR tasks are added automatically.',
      anchors: [_A.assignFirst],
    ),
  ],
};
