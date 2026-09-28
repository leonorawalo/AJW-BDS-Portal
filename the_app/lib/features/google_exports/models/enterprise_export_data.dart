import '../../calendar/models/consultation_session.dart';
import '../../calendar/models/session_person.dart';
import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../../legal_workstream/models/recommendation.dart';
import '../../legal_workstream/models/task.dart';

/// Everything an enterprise export draws on, loaded through the app's
/// normal providers — so it holds exactly what the signed-in user may see
/// (RLS): a consultant's tasks are only their discipline's, and sessions
/// only those they organised or were invited to. The scores still cover
/// every discipline, via the completion-only RPC the dashboard uses.
class EnterpriseExportData {
  const EnterpriseExportData({
    required this.enterprise,
    required this.inputs,
    required this.tasks,
    required this.recommendations,
    required this.sessions,
    required this.sessionPeople,
    required this.exportedBy,
    required this.exportedAt,
  });

  final Enterprise enterprise;
  final LoanReadinessInputs inputs;
  final List<WorkstreamTask> tasks;
  final List<Recommendation> recommendations;
  final List<ConsultationSession> sessions;
  final List<SessionPerson> sessionPeople;
  final String exportedBy;
  final DateTime exportedAt;

  double get businessHealth => LoanReadiness.businessHealthScore(inputs);
  double get creditReadiness => LoanReadiness.creditReadinessScore(inputs);
}
