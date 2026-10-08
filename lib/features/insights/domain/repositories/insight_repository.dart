import 'package:bizbrain/features/insights/domain/entities/insight.dart';

/// Read contract for insights (including the news feed) of one tenant.
///
/// Insights are AI-generated system records: they are written exclusively by
/// backend services and are read-only for clients (`firestore.rules`).
abstract interface class InsightRepository {
  Stream<List<Insight>> watchForOrganization(String organizationId);
}
