/// Model-agnostic request to an LLM.
///
/// There is deliberately no Flutter implementation: model API keys live in
/// backend secret storage, and every inference call must go through an
/// authenticated backend endpoint so it can be audited, rate limited and
/// billed per tenant.
class ModelRequest {
  const ModelRequest({
    required this.organizationId,
    required this.prompt,
    this.systemPrompt,
    this.maxTokens = 1024,
    this.temperature = 0.2,
  });

  final String organizationId;
  final String prompt;
  final String? systemPrompt;
  final int maxTokens;
  final double temperature;
}

class ModelResponse {
  const ModelResponse({
    required this.text,
    required this.modelId,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  final String text;
  final String modelId;
  final int inputTokens;
  final int outputTokens;
}

/// Abstraction over LLM vendors (Vertex AI, OpenAI-compatible endpoints, ...)
/// so the platform is not locked to one provider. Implementations are
/// backend-only.
abstract interface class AiModelProvider {
  String get providerId;

  Future<ModelResponse> generate(ModelRequest request);
}
