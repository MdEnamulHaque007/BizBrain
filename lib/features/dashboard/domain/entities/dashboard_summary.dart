/// Identifier of a dashboard tile.
enum DashboardSectionId {
  organizations,
  dataSources,
  aiInsights,
  businessAlerts,
  pendingApprovals,
  recentActivity,
}

/// Honest rendering state of a tile.
///
/// [unavailable] is used for capabilities whose backend does not exist yet -
/// it is never confused with "zero", because showing 0 for a metric that is
/// not being computed would be fabricated data.
enum DashboardSectionStatus { loading, ready, empty, unavailable, error }

/// One tile of the dashboard.
class DashboardSection {
  const DashboardSection({
    required this.id,
    required this.status,
    this.count,
    this.note,
    this.errorMessage,
  });

  final DashboardSectionId id;
  final DashboardSectionStatus status;

  /// Meaningful only when [status] is [DashboardSectionStatus.ready] or
  /// [DashboardSectionStatus.empty].
  final int? count;

  /// Explanation shown when the section has no real data yet.
  final String? note;

  final String? errorMessage;

  @override
  String toString() => 'DashboardSection($id, $status, count: $count)';
}

/// Aggregate of every dashboard tile for one user.
class DashboardSummary {
  const DashboardSummary({required this.sections});

  final List<DashboardSection> sections;

  DashboardSection section(DashboardSectionId id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return DashboardSection(id: id, status: DashboardSectionStatus.unavailable);
  }
}
