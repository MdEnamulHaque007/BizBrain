import 'package:bizbrain/features/ai_brain/domain/context/business_context_builder.dart';

/// Draft insight produced by the generator, before it is persisted.
class GeneratedInsight {
  const GeneratedInsight({
    required this.title,
    required this.summary,
    required this.severity,
    this.ruleId,
    this.confidence = 0,
  });

  final String title;
  final String summary;

  /// `info`, `warning` or `critical`.
  final String severity;
  final String? ruleId;
  final double confidence;
}

/// Turns a business context into insights (and news-feed style updates).
///
/// Runs on the backend: the generator owns the model prompt, the safety
/// checks and the write path into `organizations/{id}/insights`, which
/// clients can read but never modify.
abstract interface class InsightGenerator {
  Future<List<GeneratedInsight>> generate({
    required String organizationId,
    required BusinessContext context,
    bool includeNewsFeed = true,
  });
}
