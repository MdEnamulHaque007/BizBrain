/// A chunk of organizational knowledge (document, decision, metric
/// definition) retrieved for the model to cite.
class KnowledgeChunk {
  const KnowledgeChunk({
    required this.id,
    required this.title,
    required this.content,
    this.score = 0,
  });

  final String id;
  final String title;
  final String content;
  final double score;
}

class KnowledgeSearchResult {
  const KnowledgeSearchResult({required this.chunks, required this.query});

  final List<KnowledgeChunk> chunks;
  final String query;
}

/// Retrieval interface over the organization's business memory
/// (documents, decisions, historical notes). Vectorisation and search are
/// performed by backend services; the client only displays approved results.
abstract interface class BusinessKnowledgeRetriever {
  Future<KnowledgeSearchResult> retrieve({
    required String organizationId,
    required String query,
    int limit = 8,
  });
}
