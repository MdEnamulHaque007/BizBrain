import 'package:bizbrain/features/ai_brain/domain/context/business_context_builder.dart';

/// Kinds of specialist agents the platform plans to run.
enum AgentRole { ceo, finance, operations, sales, quality, hr }

/// Unit of work handed to an agent.
class AgentTask {
  const AgentTask({
    required this.organizationId,
    required this.objective,
    this.constraints = const <String>[],
  });

  final String organizationId;
  final String objective;
  final List<String> constraints;
}

class AgentTaskResult {
  const AgentTaskResult({
    required this.task,
    required this.summary,
    this.recommendations = const <String>[],
    this.requiresApproval = true,
  });

  final AgentTask task;
  final String summary;
  final List<String> recommendations;
  final bool requiresApproval;
}

/// A specialist agent (AI CEO, finance analyst, ...) capable of running one
/// class of business tasks.
abstract interface class AiAgent {
  String get agentId;
  AgentRole get role;

  Future<AgentTaskResult> run({
    required AgentTask task,
    required BusinessContext context,
  });
}

/// Coordinates multi-agent runs: selects agents, sequences their work and
/// collects results for the approval pipeline. Backend service.
abstract interface class AgentOrchestrator {
  Stream<String> runPlan({
    required String organizationId,
    required String objective,
  });

  Future<List<AiAgent>> availableAgents(String organizationId);
}
