/// A single executed rule evaluation.
class RuleExecutionResult {
  const RuleExecutionResult({
    required this.ruleId,
    required this.triggered,
    this.detail,
  });

  final String ruleId;
  final bool triggered;
  final String? detail;
}

/// Report of a full evaluation pass over one organization's enabled rules.
class RuleExecutionReport {
  const RuleExecutionReport({
    required this.organizationId,
    required this.executedAt,
    required this.results,
  });

  final String organizationId;
  final DateTime executedAt;
  final List<RuleExecutionResult> results;

  int get triggeredCount => results.where((result) => result.triggered).length;
}

/// Executes an organization's business rules against fresh business context.
///
/// A privileged backend service - rules may trigger automated actions that
/// require auditing and approval checks before anything happens.
abstract interface class RuleExecutor {
  Future<RuleExecutionReport> execute({
    required String organizationId,
    String? rulesetVersion,
  });
}
