const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const OpenAI = require("openai");

initializeApp();
const openAiApiKey = defineSecret("OPENAI_API_KEY");

exports.aiChat = onCall({ secrets: [openAiApiKey], region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const question = String(request.data?.question ?? "").trim();
  const businessContext = request.data?.businessContext;
  if (!question) throw new HttpsError("invalid-argument", "question is required.");
  if (!businessContext || typeof businessContext !== "object") {
    throw new HttpsError("invalid-argument", "businessContext is required.");
  }
  const client = new OpenAI({ apiKey: openAiApiKey.value() });
  const response = await client.responses.create({
    model: "gpt-5.6",
    instructions: "You are BizBrain, a business data analyst. Answer only from the supplied business context. If data is insufficient, say exactly what is missing. Do calculations carefully. Reply in the user's language.",
    input: JSON.stringify({ question, businessContext }),
  });
  return { answer: response.output_text, model: "gpt-5.6" };
});