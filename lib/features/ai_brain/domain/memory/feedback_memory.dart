/// Feedback a user gives about an AI output (useful / not useful, correction,
/// or an approval decision). Feeds the long-term business memory.
class FeedbackEntry {
  const FeedbackEntry({
    required this.organizationId,
    required this.targetId,
    required this.rating,
    this.comment,
    this.authorId,
  });

  final String organizationId;

  /// Id of the insight / recommendation / rule this feedback refers to.
  final String targetId;

  /// `approved`, `rejected`, `useful`, `not_useful` - kept as a string so new
  /// feedback kinds can be added without a client release.
  final String rating;
  final String? comment;
  final String? authorId;
}

/// Records and replays user feedback so future model calls can be steered by
/// what the organization previously accepted or rejected.
abstract interface class FeedbackMemory {
  Future<void> record(FeedbackEntry entry);

  Stream<List<FeedbackEntry>> watchForOrganization(String organizationId);
}
