/// Aggregated, tenant-scoped snapshot of the facts an AI agent is allowed to
/// see. Built by the backend from the organization's Firestore data and
/// recent connector payloads.
class BusinessContext {
  const BusinessContext({
    required this.organizationId,
    required this.generatedAt,
    this.facts = const <String, dynamic>{},
    this.knowledgeRefs = const <String>[],
  });

  final String organizationId;
  final DateTime generatedAt;

  /// Pre-aggregated metrics, labels and time series.
  final Map<String, dynamic> facts;

  /// Ids of knowledge entries the model may cite.
  final List<String> knowledgeRefs;
}

/// Builds a [BusinessContext] for a time window.
///
/// Runs entirely on the backend so that raw business data never has to be
/// copied into the client to feed an LLM.
abstract interface class BusinessContextBuilder {
  Future<BusinessContext> build({
    required String organizationId,
    DateTime? from,
    DateTime? to,
  });
}
