/// An action the AI wants to perform that needs a human decision.
class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.requestedAt,
    this.decidedAt,
    this.decision,
    this.decidedBy,
  });

  final String id;
  final String organizationId;
  final String title;
  final String description;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  /// `pending`, `approved` or `rejected`.
  final String? decision;
  final String? decidedBy;

  bool get isPending => decision == null || decision == 'pending';
}

/// Human-in-the-loop approval pipeline.
///
/// No automated action may execute without passing through this workflow;
/// decisions are written server-side with the acting user's identity so the
/// audit trail cannot be forged from the client.
abstract interface class ApprovalWorkflow {
  Stream<List<ApprovalRequest>> watchPending(String organizationId);

  Future<void> decide({
    required String organizationId,
    required String requestId,
    required bool approved,
    required String decidedBy,
    String? comment,
  });
}
