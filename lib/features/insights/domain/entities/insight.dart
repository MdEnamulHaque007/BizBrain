/// Impact level of an insight.
enum InsightSeverity { info, warning, critical }

/// Where an insight came from.
enum InsightSource { aiModel, businessRule, anomalyDetector, system }

/// An insight produced by the AI brain for one organization.
class Insight {
  const Insight({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.summary,
    required this.severity,
    required this.source,
    required this.createdAt,
    this.approvalRequired = false,
  });

  final String id;
  final String organizationId;
  final String title;
  final String summary;
  final InsightSeverity severity;
  final InsightSource source;
  final DateTime createdAt;

  /// True when acting on this insight requires human approval.
  final bool approvalRequired;

  @override
  String toString() => 'Insight($id, $severity, source: $source)';
}
