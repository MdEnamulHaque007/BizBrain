const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
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

const OWNER_ROLES = new Set(["owner", "admin"]);

function normalizeOrganizationName(raw) {
  const name = String(raw ?? "").trim();
  if (!name || name.length > 60) {
    throw new HttpsError("invalid-argument", "name is required and at most 60 characters.");
  }
  return name;
}

exports.createOrganization = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const name = normalizeOrganizationName(request.data?.name);
  const uid = request.auth.uid;
  const now = new Date();
  const orgRef = db.collection("organizations").doc();
  await db.runTransaction(async (tx) => {
    tx.set(orgRef, {
      name,
      ownerId: uid,
      memberIds: [uid],
      status: "active",
      createdAt: now,
      createdBy: uid,
    });
    tx.set(orgRef.collection("members").doc(uid), {
      userId: uid,
      role: "owner",
      status: "active",
      joinedAt: now,
    });
  });
  return { id: orgRef.id, name };
});

exports.listOrganizations = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const uid = request.auth.uid;
  const memberships = await db
    .collectionGroup("members")
    .where("userId", "==", uid)
    .where("status", "==", "active")
    .get();
  const organizations = [];
  for (const membership of memberships.docs) {
    const organizationId = membership.ref.path.split("/")[1];
    const doc = await db.collection("organizations").doc(organizationId).get();
    if (!doc.exists || doc.data().status !== "active") continue;
    const data = doc.data();
    organizations.push({
      id: doc.id,
      name: data.name,
      ownerId: data.ownerId,
      memberIds: data.memberIds || [],
      status: data.status,
      createdAt: data.createdAt,
    });
  }
  return { organizations };
});

exports.addMember = onCall({ region: "asia-south1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  const organizationId = String(request.data?.orgId ?? "").trim();
  const userId = String(request.data?.userId ?? "").trim();
  const rawRole = String(request.data?.role ?? "member").trim();
  if (!organizationId) throw new HttpsError("invalid-argument", "orgId is required.");
  if (!userId) throw new HttpsError("invalid-argument", "userId is required.");
  if (!["owner", "admin", "manager", "member", "viewer"].includes(rawRole)) {
    throw new HttpsError("invalid-argument", "role must be one of: owner, admin, manager, member, viewer.");
  }
  const requesterUid = request.auth.uid;
  const orgRef = db.collection("organizations").doc(organizationId);
  await db.runTransaction(async (tx) => {
    const orgDoc = await tx.get(orgRef);
    if (!orgDoc.exists) {
      throw new HttpsError("not-found", "Organization does not exist.");
    }
    const requesterMember = await tx.get(orgRef.collection("members").doc(requesterUid));
    const requesterData = requesterMember.data() || {};
    if (!OWNER_ROLES.has(requesterData.role)) {
      throw new HttpsError("permission-denied", "Only owners and admins can add members.");
    }
    tx.set(orgRef.collection("members").doc(userId), {
      userId,
      role: rawRole,
      status: "active",
      joinedAt: new Date(),
    });
    tx.update(orgRef, { memberIds: FieldValue.arrayUnion([userId]) });
  });
  return { organizationId, userId };
});
