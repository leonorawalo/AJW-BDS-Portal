enum LifecycleStatus {
  newEnterprise,
  active,
  underAssessment,
  inProgress,
  loanReady,
  graduated,
  inactive,
}

extension LifecycleStatusX on LifecycleStatus {
  static LifecycleStatus fromDb(String value) {
    switch (value) {
      case 'New':
        return LifecycleStatus.newEnterprise;
      case 'Active':
        return LifecycleStatus.active;
      case 'Under Assessment':
        return LifecycleStatus.underAssessment;
      case 'In Progress':
        return LifecycleStatus.inProgress;
      case 'Loan Ready':
        return LifecycleStatus.loanReady;
      case 'Graduated':
        return LifecycleStatus.graduated;
      case 'Inactive':
        return LifecycleStatus.inactive;
      default:
        throw ArgumentError('Unknown lifecycle_status: $value');
    }
  }

  String get dbValue {
    switch (this) {
      case LifecycleStatus.newEnterprise:
        return 'New';
      case LifecycleStatus.active:
        return 'Active';
      case LifecycleStatus.underAssessment:
        return 'Under Assessment';
      case LifecycleStatus.inProgress:
        return 'In Progress';
      case LifecycleStatus.loanReady:
        return 'Loan Ready';
      case LifecycleStatus.graduated:
        return 'Graduated';
      case LifecycleStatus.inactive:
        return 'Inactive';
    }
  }

  String get label => dbValue; // display label matches db value 1:1 for now
}

enum GoingConcernStatus { notYet, achieved }

extension GoingConcernStatusX on GoingConcernStatus {
  static GoingConcernStatus fromDb(String value) {
    return value == 'Achieved' ? GoingConcernStatus.achieved : GoingConcernStatus.notYet;
  }

  String get dbValue => this == GoingConcernStatus.achieved ? 'Achieved' : 'Not Yet';
}

class Enterprise {
  const Enterprise({
    required this.id,
    required this.businessName,
    required this.ownerName,
    this.ownerUserId,
    this.phoneNumber,
    this.email,
    this.county,
    this.industry,
    this.registrationNumber,
    this.kraPin,
    required this.lifecycleStatus,
    required this.goingConcernStatus,
    this.goingConcernAchievedAt,
    required this.enrolledAt,
  });

  factory Enterprise.fromMap(Map<String, dynamic> map) {
    return Enterprise(
      id: map['id'] as String,
      businessName: map['business_name'] as String,
      ownerName: map['owner_name'] as String,
      ownerUserId: map['owner_user_id'] as String?,
      phoneNumber: map['phone_number'] as String?,
      email: map['email'] as String?,
      county: map['county'] as String?,
      industry: map['industry'] as String?,
      registrationNumber: map['registration_number'] as String?,
      kraPin: map['kra_pin'] as String?,
      lifecycleStatus: LifecycleStatusX.fromDb(map['lifecycle_status'] as String),
      goingConcernStatus: GoingConcernStatusX.fromDb(map['going_concern_status'] as String),
      goingConcernAchievedAt: map['going_concern_achieved_at'] != null
          ? DateTime.parse(map['going_concern_achieved_at'] as String)
          : null,
      enrolledAt: DateTime.parse(map['enrolled_at'] as String),
    );
  }

  final String id;
  final String businessName;
  final String ownerName;
  final String? ownerUserId;
  final String? phoneNumber;
  final String? email;
  final String? county;
  final String? industry;
  final String? registrationNumber;
  final String? kraPin;
  final LifecycleStatus lifecycleStatus;
  final GoingConcernStatus goingConcernStatus;
  final DateTime? goingConcernAchievedAt;
  final DateTime enrolledAt;

  /// Months since enrolment — used to surface the TOR's "50% Going Concern
  /// within 3 months" KPI against the same baseline for every enterprise.
  int get monthsSinceEnrolment {
    final now = DateTime.now();
    return (now.year - enrolledAt.year) * 12 + (now.month - enrolledAt.month);
  }
}