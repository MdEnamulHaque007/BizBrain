const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const OpenAI = require("openai");

initializeApp();
const db = getFirestore();
const openAiApiKey = defineSecret("OPENAI_API_KEY");

exports.aiChat = onCall({ secrets: [openAiApiKey], region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const question = String(request.data?.question ?? "").trim();
  const businessContext = request.data?.businessContext;
  if (!question) throw new HttpsError("invalid-argument", "question is required.");
  if (!businessContext || typeof businessContext !== "object") {
    throw new HttpsError("invalid-argument", "businessContext is required.");
  }
  const configDoc = await db.collection("ai_model_settings").doc(request.auth.uid).get();
  const config = configDoc.data() || {};
  const model = String(config.model || "gpt-5.6");
  const client = new OpenAI({ apiKey: openAiApiKey.value() });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await client.responses.create(
      {
        model,
        instructions: "You are BizBrain, a business data analyst. Answer only from the supplied business context. If data is insufficient, say exactly what is missing. Do calculations carefully. Reply in the user's language.",
        input: JSON.stringify({ question, businessContext }),
      },
      { signal: controller.signal },
    );
    return { answer: response.output_text, model };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("aiChat request failed:", message);
    const timedOut = controller.signal.aborted || /abort|timeout/i.test(message);
    if (timedOut) {
      throw new HttpsError("deadline-exceeded", "AI request timed out after 30s.");
    }
    throw new HttpsError("unavailable", `AI request failed: ${message}`);
  } finally {
    clearTimeout(timer);
  }
});

exports.saveAiModelSettings = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const provider = String(request.data?.provider || "openai").trim();
  const model = String(request.data?.model || "").trim();
  if (provider !== "openai") throw new HttpsError("invalid-argument", "Only OpenAI is enabled right now.");
  if (!model) throw new HttpsError("invalid-argument", "model is required.");
  await db.collection("ai_model_settings").doc(request.auth.uid).set({ provider, model, updatedAt: new Date().toISOString() }, { merge: true });
  return { provider, model, apiKeyConfigured: Boolean(openAiApiKey.value()) };
});

exports.getAiModelSettings = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const doc = await db.collection("ai_model_settings").doc(request.auth.uid).get();
  const data = doc.data() || {};
  return { provider: data.provider || "openai", model: data.model || "gpt-5.6" };
});
