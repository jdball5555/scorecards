// Optic integration: lets the Optic developer app (Axis Team's Firebase
// project) see and manage Scorecards.
//
//   opticNewUser  a new Scorecards account -> "new user" alert in Optic
//   opticAdmin    Optic's user admin: list users, view a user, change their
//                 settings (name, email, sign-in, notifications, premium beta)
//
// Both directions use Google-signed identity tokens from each project's Cloud
// Functions service account, so there are no secrets to set up:
//   this project -> reportAppEvent (project-attendance-app)
//   project-attendance-app's opticService -> opticAdmin (here)
//
// To plug another app into Optic, copy this file into its functions, change
// the APP section (field names, settings, stats), require it from index.js,
// and add the app to EXTERNAL_APPS in axis-team/functions/index.js and to
// kServices in Optic (lib/services.dart).

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { OAuth2Client } = require("google-auth-library");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const oidc = new OAuth2Client();

const REPORT_EVENT_URL =
  "https://us-central1-project-attendance-app.cloudfunctions.net/reportAppEvent";
const ADMIN_URL = "https://us-central1-scorecards-app.cloudfunctions.net/opticAdmin";

// Axis Team's Cloud Functions accounts (where Optic's opticService runs).
const OPTIC_SERVICE_ACCOUNTS = [
  "282213766426-compute@developer.gserviceaccount.com",
  "project-attendance-app@appspot.gserviceaccount.com",
];

// ---------------------------------------------------------------------------
// APP: what Optic shows and can change for a Scorecards user.
// ---------------------------------------------------------------------------
const APP_COLOR = "#7855C1";

// users/{uid}.notificationSettings keys (same list as the app's Settings page).
const NOTIFICATION_SETTINGS = [
  ["invite_received", "Invited to a group"],
  ["removed_from_group", "Removed from a group"],
  ["group_deleted", "Group gets deleted"],
  ["new_player_added", "Player added to group"],
  ["player_removed", "Player removed from group"],
  ["player_left", "Player leaves group"],
  ["new_player_linked", "New player linked in a group"],
  ["invite_accepted", "Someone accepts their invite"],
  ["new_scorecard_added", "New scorecard in group"],
];

// Premium beta: early features for accounts switched on here in Optic (right
// now: custom templates). Stored as the sign-in claim `premiumBeta`, which
// only this server can set; users/{uid}.premiumBeta is a copy the app
// watches so it notices the change right away.
const PREMIUM_BETA_NOTE =
  "Early features for this account. Right now: custom templates (the template builder, saved templates and the AI rulebook scan). " +
  "They see a small \"Premium beta\" note in Settings.";

function hasPremiumBeta(u) {
  return !!(u.customClaims && u.customClaims.premiumBeta === true);
}

async function setPremiumBeta(uid, on) {
  const u = await auth.getUser(uid);
  const claims = { ...(u.customClaims || {}) };
  if (on) claims.premiumBeta = true;
  else delete claims.premiumBeta;
  await auth.setCustomUserClaims(uid, claims);
  // The copy the app listens to, so it refreshes its sign-in now.
  await db.collection("users").doc(uid).set({ premiumBeta: on }, { merge: true });
}

function providerLabel(id) {
  return { password: "Email", "google.com": "Google", "apple.com": "Apple" }[id] || id;
}

function iso(v) {
  if (!v) return null;
  if (typeof v.toDate === "function") return v.toDate().toISOString();
  const d = new Date(v);
  return isNaN(d) ? null : d.toISOString();
}

async function countWhere(collection, field, value) {
  try {
    const snap = await db.collection(collection).where(field, "==", value).count().get();
    return snap.data().count;
  } catch (_) {
    return null;
  }
}

async function allAuthUsers(limit = 5000) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken && users.length < limit);
  return users;
}

const actions = {
  async summary() {
    const users = await allAuthUsers();
    const weekAgo = Date.now() - 7 * 24 * 3600 * 1000;
    const newThisWeek = users.filter((u) => new Date(u.metadata.creationTime).getTime() > weekAgo).length;
    const count = async (c) => {
      try {
        return (await db.collection(c).count().get()).data().count;
      } catch (_) {
        return null;
      }
    };
    return {
      stats: [
        { label: "Users", value: users.length },
        { label: "New this week", value: newThisWeek },
        { label: "Groups", value: await count("game_groups") },
        { label: "Scorecards", value: await count("scorecards") },
        { label: "Premium beta", value: users.filter(hasPremiumBeta).length },
      ],
    };
  },

  async listUsers() {
    const [authUsers, docs] = await Promise.all([allAuthUsers(), db.collection("users").get()]);
    const byUid = new Map(docs.docs.map((d) => [d.id, d.data()]));
    const users = authUsers.map((u) => {
      const d = byUid.get(u.uid) || {};
      return {
        uid: u.uid,
        name: d.displayName || u.displayName || "",
        email: u.email || d.email || "",
        created: iso(u.metadata.creationTime),
        lastActive: iso(u.metadata.lastRefreshTime || u.metadata.lastSignInTime),
        disabled: u.disabled,
        tags: [
          ...u.providerData.map((p) => providerLabel(p.providerId)),
          ...(hasPremiumBeta(u) ? ["Premium beta"] : []),
        ],
      };
    });
    users.sort((a, b) => String(b.created).localeCompare(String(a.created)));
    return { users };
  },

  async getUser({ uid }) {
    if (!uid) throw httpError(400, "uid is required");
    let u;
    try {
      u = await auth.getUser(uid);
    } catch (e) {
      throw httpError(404, "That user doesn't exist anymore.");
    }
    const doc = await db.collection("users").doc(uid).get();
    const d = doc.data() || {};
    const notif = d.notificationSettings || {};

    const groupsSnap = await db.collection("game_groups").where("members", "array-contains", uid).limit(25).get();
    const groups = groupsSnap.docs.map((g) => {
      const gd = g.data();
      const members = (gd.members || []).length + (gd.localMembers || []).length;
      return {
        type: "info",
        label: gd.name || g.id,
        value: `${members} player${members === 1 ? "" : "s"}${gd.owner === uid ? " · owner" : ""}`,
      };
    });

    const [submitted, personal] = await Promise.all([
      countWhere("scorecards", "submittedBy", uid),
      countWhere("scorecards", "ownerId", uid),
    ]);

    const user = {
      uid,
      name: d.displayName || u.displayName || "",
      email: u.email || d.email || "",
      created: iso(u.metadata.creationTime),
      lastActive: iso(u.metadata.lastRefreshTime || u.metadata.lastSignInTime),
      disabled: u.disabled,
      tags: u.providerData.map((p) => providerLabel(p.providerId)),
    };

    return {
      user,
      sections: [
        {
          title: "Account",
          fields: [
            { key: "displayName", type: "text", label: "Display name", value: user.name },
            { key: "email", type: "text", label: "Email", value: user.email, hint: "Changes their sign-in email too." },
            {
              key: "disabled",
              type: "bool",
              label: "Block sign-in",
              value: u.disabled,
              hint: "Disables the account and signs them out everywhere.",
              danger: true,
            },
            { type: "info", label: "Signs in with", value: user.tags.join(", ") || "—" },
            { type: "info", label: "Joined", value: user.created, format: "date" },
            { type: "info", label: "Last active", value: user.lastActive, format: "date" },
            { type: "info", label: "Phone notifications", value: d.fcmToken ? "Device registered" : "No device" },
            { type: "info", label: "User ID", value: uid, copy: true },
          ],
        },
        {
          title: "Premium beta",
          note: PREMIUM_BETA_NOTE,
          fields: [
            {
              key: "premiumBeta",
              type: "bool",
              label: "Premium beta",
              value: hasPremiumBeta(u),
            },
          ],
        },
        {
          title: "Notifications",
          note: "The push notifications this person gets from Scorecards.",
          fields: NOTIFICATION_SETTINGS.map(([key, label]) => ({
            key: `notif.${key}`,
            type: "bool",
            label,
            value: notif[key] !== false,
          })),
        },
        {
          title: "Activity",
          fields: [
            { type: "info", label: "Scorecards submitted", value: submitted == null ? "—" : String(submitted) },
            { type: "info", label: "Personal scorecards", value: personal == null ? "—" : String(personal) },
            { type: "info", label: "Groups", value: String(groupsSnap.size) },
          ],
        },
        ...(groups.length ? [{ title: "Groups", fields: groups }] : []),
      ],
      actions: [
        {
          id: "revoke_sessions",
          label: "Sign out everywhere",
          icon: "logout",
          confirm: "They'll have to sign in again on every device.",
        },
        ...(u.providerData.some((p) => p.providerId === "password")
          ? [{ id: "password_reset_link", label: "Get a password reset link", icon: "key" }]
          : []),
      ],
    };
  },

  async updateUser({ uid, changes, by }) {
    if (!uid || !changes || typeof changes !== "object") throw httpError(400, "uid and changes are required");
    const authUpdate = {};
    const docUpdate = {};
    let premiumBeta;
    for (const [key, value] of Object.entries(changes)) {
      if (key === "premiumBeta") {
        premiumBeta = value === true;
      } else if (key === "displayName") {
        const name = String(value || "").trim().slice(0, 60);
        if (!name) throw httpError(400, "Display name can't be empty.");
        authUpdate.displayName = name;
        docUpdate.displayName = name;
      } else if (key === "email") {
        const email = String(value || "").trim().toLowerCase();
        if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw httpError(400, "That isn't a valid email.");
        authUpdate.email = email;
        docUpdate.email = email;
      } else if (key === "disabled") {
        authUpdate.disabled = value === true;
      } else if (key.startsWith("notif.") && NOTIFICATION_SETTINGS.some(([k]) => `notif.${k}` === key)) {
        docUpdate.notificationSettings = { ...(docUpdate.notificationSettings || {}), [key.slice(6)]: value === true };
      } else {
        throw httpError(400, `Unknown setting "${key}".`);
      }
    }
    try {
      if (Object.keys(authUpdate).length) await auth.updateUser(uid, authUpdate);
    } catch (e) {
      if (e.code === "auth/email-already-exists") throw httpError(400, "Another account already uses that email.");
      if (e.code === "auth/user-not-found") throw httpError(404, "That user doesn't exist anymore.");
      throw e;
    }
    if (authUpdate.disabled === true) await auth.revokeRefreshTokens(uid);
    if (premiumBeta !== undefined) await setPremiumBeta(uid, premiumBeta);
    if (Object.keys(docUpdate).length) {
      await db.collection("users").doc(uid).set(docUpdate, { merge: true });
    }
    functions.logger.info(`Optic (${by}) updated ${uid}`, Object.keys(changes));
    return { ok: true };
  },

  async userAction({ uid, id, by }) {
    if (!uid || !id) throw httpError(400, "uid and id are required");
    functions.logger.info(`Optic (${by}) ran ${id} on ${uid}`);
    if (id === "revoke_sessions") {
      await auth.revokeRefreshTokens(uid);
      return { message: "Signed out on every device." };
    }
    if (id === "password_reset_link") {
      const u = await auth.getUser(uid);
      if (!u.email) throw httpError(400, "They have no email.");
      const link = await auth.generatePasswordResetLink(u.email);
      return { message: "Reset link copied. Send it to them.", copy: link };
    }
    throw httpError(400, `Unknown action "${id}".`);
  },
};

// ---------------------------------------------------------------------------
// Plumbing (same for every app).
// ---------------------------------------------------------------------------
function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

/** A Google identity token from this function's service account, for `audience`. */
async function googleIdentityToken(audience) {
  const url =
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity" +
    `?format=full&audience=${encodeURIComponent(audience)}`;
  const r = await fetch(url, { headers: { "Metadata-Flavor": "Google" } });
  if (!r.ok) throw new Error(`metadata identity token: HTTP ${r.status}`);
  return r.text();
}

/** Sends an alert to Optic (it decides whether to push it, per its Alerts settings). */
async function reportToOptic(event, { title, body, data = {} }) {
  try {
    const token = await googleIdentityToken(REPORT_EVENT_URL);
    const res = await fetch(REPORT_EVENT_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify({ event, title, body, data, color: APP_COLOR }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) functions.logger.warn(`Optic event ${event}: HTTP ${res.status}`, await res.text());
  } catch (e) {
    functions.logger.warn(`Optic event ${event} not sent`, e);
  }
}

exports.opticNewUser = functions.auth.user().onCreate(async (user) => {
  const how = user.providerData.map((p) => providerLabel(p.providerId)).join(", ");
  const who = user.displayName || user.email || "Someone";
  await reportToOptic("new_user", {
    title: "🃏 New Scorecards user",
    body: `${who}${user.displayName && user.email ? ` (${user.email})` : ""}${how ? ` · ${how}` : ""}`,
    data: { uid: user.uid },
  });
});

// Only Axis Team's functions may call this (Cloud IAM), on top of the token
// check below.
exports.opticAdmin = functions.runWith({ invoker: OPTIC_SERVICE_ACCOUNTS }).https.onRequest(async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
  const token = String(req.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  try {
    const ticket = await oidc.verifyIdToken({ idToken: token, audience: ADMIN_URL });
    const p = ticket.getPayload() || {};
    if (!p.email_verified || !OPTIC_SERVICE_ACCOUNTS.includes(String(p.email).toLowerCase())) {
      throw new Error(`untrusted caller ${p.email || p.sub}`);
    }
  } catch (e) {
    functions.logger.warn("opticAdmin: rejected", e.message);
    return res.status(403).json({ error: "Not allowed" });
  }

  const body = req.body || {};
  const handler = Object.prototype.hasOwnProperty.call(actions, body.action) && actions[body.action];
  if (!handler) return res.status(400).json({ error: `Unknown action "${body.action}"` });
  try {
    return res.status(200).json(await handler(body));
  } catch (e) {
    if (e.status) return res.status(e.status).json({ error: e.message });
    functions.logger.error(`opticAdmin ${body.action} failed`, e);
    return res.status(500).json({ error: "Something went wrong in Scorecards." });
  }
});
