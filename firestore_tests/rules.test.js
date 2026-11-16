// Tests for firestore.rules: what the app does must be allowed, and the
// attacks below must be blocked. Run with `npm test` in this folder (needs
// Java for the Firestore emulator).
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const firebase = require("firebase/compat/app");
require("firebase/compat/firestore");
const FV = firebase.firestore.FieldValue;

const RULES = path.resolve(process.argv[2] || path.join(__dirname, "..", "firestore.rules"));
let env;
const results = [];

async function check(name, expectOk, fn) {
  try {
    if (expectOk) await assertSucceeds(fn());
    else await assertFails(fn());
    results.push(["PASS", name]);
  } catch (e) {
    results.push(["FAIL", name + "  ->  " + (e.message || e).toString().split("\n")[0]]);
  }
}

const as = (uid, claims = {}) =>
  env.authenticatedContext(uid, { email: `${uid}@test.com`, ...claims }).firestore();

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const u of ["alice", "bob", "carol", "dave", "eve"]) {
      await db.doc(`users/${u}`).set({ uid: u, email: `${u}@test.com`, displayName: u, fcmToken: "tok" });
    }
    await db.doc("game_groups/g1").set({
      name: "Family", owner: "alice", id: "g1", members: ["alice", "bob"],
      localMembers: [{ id: "local_1", name: "Grandma" }, { id: "local_2", name: "Grandpa" }],
      guests: [], hiddenPlayers: ["local_1"],
    });
    await db.doc("game_groups/g2").set({ name: "Other", owner: "eve", id: "g2", members: ["eve"], localMembers: [], guests: [] });
    await db.doc("scorecards/s_group").set({ id: "s_group", ownerType: "group", ownerId: "g1", playerIds: ["alice", "local_1"], playerNames: ["alice", "Grandma"] });
    await db.doc("scorecards/s_alice").set({ id: "s_alice", ownerType: "person", ownerId: "alice" });
    await db.doc("scorecards/s_g2").set({ id: "s_g2", ownerType: "group", ownerId: "g2" });
    await db.doc("player_invites/tok1").set({ groupId: "g1", groupName: "Family", localPlayerId: "local_1", localPlayerName: "Grandma", createdBy: "alice", usedBy: null });
    await db.doc("player_invites/tokUsed").set({ groupId: "g1", localPlayerId: "local_2", createdBy: "alice", usedBy: "bob" });
    await db.doc("users/carol/mail/inv1").set({ type: "invite_received", groupId: "g1", groupName: "Family", senderUid: "alice", targetUid: "carol", status: "pending", localPlayerIdToReplace: "local_2", localPlayerNameToReplace: "Grandpa" });
    await db.doc("users/alice/mail/m1").set({ type: "system_notice", message: "hi", status: "unread" });
    await db.doc("scorecard_templates/t1").set({ creatorId: "alice", templateName: "Mine", isPublished: true });
    await db.doc("feedback/f1").set({ uid: "alice", text: "x" });
  });
}

const notice = (groupId, sender, msg = "note") => ({
  type: "system_notice", groupId, senderUid: sender, message: msg, createdAt: FV.serverTimestamp(),
});

async function main() {
  env = await initializeTestEnvironment({
    projectId: "demo-scorecards",
    firestore: { rules: fs.readFileSync(RULES, "utf8"), host: "127.0.0.1", port: 8080 },
  });

  // ---------- Things the app does: must work ----------
  await seed();
  const alice = as("alice"), bob = as("bob"), carol = as("carol"), dave = as("dave"), eve = as("eve");

  await check("read own profile", true, () => alice.doc("users/alice").get());
  await check("read a group member's profile", true, () => bob.doc("users/alice").get());
  await check("save own profile (merge)", true, () => alice.doc("users/alice").set({ displayName: "Al", metricsDefault: { a: 1 }, fcmToken: "t2" }, { merge: true }));
  await check("new account creates profile", true, () => as("newbie").doc("users/newbie").set({ uid: "newbie", email: "newbie@test.com", displayName: "N" }, { merge: true }));
  await check("list my groups", true, () => alice.collection("game_groups").where("members", "array-contains", "alice").get());
  await check("stream a group I'm in", true, () => bob.doc("game_groups/g1").get());
  await check("my personal scorecards", true, () => alice.collection("scorecards").where("ownerType", "==", "person").where("ownerId", "==", "alice").get());
  await check("group scorecards (whereIn)", true, () => alice.collection("scorecards").where("ownerType", "==", "group").where("ownerId", "in", ["g1"]).get());
  await check("group scorecards (one group)", true, () => alice.collection("scorecards").where("ownerType", "==", "group").where("ownerId", "==", "g1").get());
  await check("open a group scorecard from mail", true, () => bob.doc("scorecards/s_group").get());
  await check("member saves group scorecard", true, () => bob.doc("scorecards/s_group").set({ id: "s_group", ownerType: "group", ownerId: "g1", rounds: [], isFinalized: true }));
  await check("member creates group scorecard", true, () => bob.doc("scorecards/new1").set({ id: "new1", ownerType: "group", ownerId: "g1" }));
  await check("create personal scorecard", true, () => carol.doc("scorecards/c1").set({ id: "c1", ownerType: "person", ownerId: "carol" }));
  await check("member deletes group scorecard", true, () => bob.doc("scorecards/new1").delete());
  await check("create group", true, () => carol.doc("game_groups/gc").set({ name: "C", owner: "carol", id: "gc", members: ["carol"], localMembers: [], guests: [] }));
  await check("add local player + notify members", true, () => {
    const b = bob.batch();
    b.update(bob.doc("game_groups/g1"), { localMembers: FV.arrayUnion({ id: "local_3", name: "Kid" }) });
    b.set(bob.collection("users/alice/mail").doc(), notice("g1", "bob", 'bob added local player "Kid" to "Family".'));
    return b.commit();
  });
  await check("rename / hide players", true, () => bob.doc("game_groups/g1").update({ hiddenPlayers: FV.arrayUnion("local_2") }));
  await check("mark my mail read", true, () => alice.doc("users/alice/mail/m1").update({ status: "read" }));
  await check("invite someone by email (mail invite)", true, () => alice.doc("users/carol/mail/x1").set({
    groupId: "g1", groupName: "Family", targetUid: "carol", targetEmail: "carol@test.com", targetName: "carol",
    senderName: "alice", senderUid: "alice", status: "pending", type: "invite_received", createdAt: FV.serverTimestamp() }));
  await check("create invite link", true, () => alice.doc("player_invites/tokNew").set({ groupId: "g1", groupName: "Family", localPlayerId: "local_2", localPlayerName: "Grandpa", createdBy: "alice", createdAt: FV.serverTimestamp(), usedBy: null }));
  await check("find existing invite link", true, () => alice.collection("player_invites").where("groupId", "==", "g1").where("localPlayerId", "==", "local_2").get());
  await check("update names on invite link", true, () => alice.doc("player_invites/tokNew").update({ localPlayerName: "Gramps", groupName: "Family" }));
  await check("open invite link before joining", true, () => dave.doc("player_invites/tok1").get());
  await check("premium: save template", true, () => as("alice", { premiumBeta: true }).collection("scorecard_templates").add({ creatorId: "alice", templateName: "T" }));
  await check("list my templates", true, () => alice.collection("scorecard_templates").where("creatorId", "==", "alice").get());
  await check("delete my template (not premium)", true, () => alice.doc("scorecard_templates/t1").delete());
  await check("send feedback", true, () => alice.collection("feedback").add({ uid: "alice", email: "a", text: "Great app", type: "idea" }));

  // Accept a mail invite (step 1: join, step 2: take the local player's place).
  await check("accept invite: join", true, () => {
    const b = carol.batch();
    b.update(carol.doc("users/carol/mail/inv1"), { status: "accepted" });
    b.update(carol.doc("game_groups/g1"), { members: FV.arrayUnion("carol"), joinedVia: { type: "mail", id: "inv1" } });
    return b.commit();
  });
  await check("accept invite: replace local player + notify", true, () => {
    const b = carol.batch();
    b.update(carol.doc("game_groups/g1"), { localMembers: [{ id: "local_1", name: "Grandma" }], guests: [] });
    b.set(carol.collection("users/alice/mail").doc(), notice("g1", "carol", 'carol accepted your invite to "Family"!'));
    b.set(carol.collection("users/bob/mail").doc(), notice("g1", "carol"));
    return b.commit();
  });
  await check("accept invite: move history", true, () => carol.doc("scorecards/s_group").update({ playerIds: ["alice", "carol"] }));

  // Invite link (step 1 batch + step 2).
  await check("invite link: join", true, () => {
    const b = dave.batch();
    b.update(dave.doc("game_groups/g1"), { members: FV.arrayUnion("dave"), joinedVia: { type: "link", id: "tok1" } });
    b.update(dave.doc("player_invites/tok1"), { usedBy: "dave", usedAt: FV.serverTimestamp() });
    return b.commit();
  });
  await check("invite link: take player's place + notify", true, () => {
    const b = dave.batch();
    b.update(dave.doc("game_groups/g1"), { localMembers: [], hiddenPlayers: ["dave"] });
    for (const m of ["alice", "bob", "carol"]) b.set(dave.collection(`users/${m}/mail`).doc(), notice("g1", "dave"));
    return b.commit();
  });

  // Owner actions.
  await check("transfer ownership", true, () => {
    const b = alice.batch();
    b.update(alice.doc("game_groups/g1"), { owner: "bob" });
    for (const m of ["alice", "bob", "carol", "dave"]) b.set(alice.collection(`users/${m}/mail`).doc(), notice("g1", "alice"));
    return b.commit();
  });
  await check("owner kicks someone + notices", true, () => {
    const b = bob.batch();
    b.update(bob.doc("game_groups/g1"), { members: FV.arrayRemove("dave") });
    b.set(bob.collection("users/dave/mail").doc(), notice("g1", "bob", 'You got kicked out of "Family" by bob.'));
    for (const m of ["alice", "bob", "carol"]) b.set(bob.collection(`users/${m}/mail`).doc(), notice("g1", "bob"));
    return b.commit();
  });
  await check("member leaves + notices", true, () => {
    const b = carol.batch();
    b.update(carol.doc("game_groups/g1"), { members: FV.arrayRemove("carol") });
    for (const m of ["alice", "bob", "carol"]) b.set(carol.collection(`users/${m}/mail`).doc(), notice("g1", "carol"));
    return b.commit();
  });
  await check("owner deletes group + notices", true, () => {
    const b = bob.batch();
    b.delete(bob.doc("game_groups/g1"));
    for (const m of ["alice", "bob"]) b.set(bob.collection(`users/${m}/mail`).doc(), notice("g1", "bob"));
    return b.commit();
  });

  // ---------- Attacks: must be blocked ----------
  await seed();
  const A = as("alice"), B = as("bob"), C = as("carol");

  await check("BLOCK stranger reads a group", false, () => C.doc("game_groups/g1").get());
  await check("BLOCK list all groups", false, () => C.collection("game_groups").get());
  await check("BLOCK stranger queries a group's members", false, () => C.collection("game_groups").where("members", "array-contains", "alice").get());
  await check("BLOCK stranger reads group scorecard", false, () => C.doc("scorecards/s_group").get());
  await check("BLOCK read someone's personal scorecard", false, () => B.doc("scorecards/s_alice").get());
  await check("BLOCK list all scorecards", false, () => C.collection("scorecards").get());
  await check("BLOCK query another group's scorecards", false, () => A.collection("scorecards").where("ownerType", "==", "group").where("ownerId", "==", "g2").get());
  await check("BLOCK whereIn with a group I'm not in", false, () => A.collection("scorecards").where("ownerType", "==", "group").where("ownerId", "in", ["g1", "g2"]).get());
  await check("BLOCK overwrite another group's scorecard", false, () => A.doc("scorecards/s_g2").set({ ownerType: "group", ownerId: "g1" }));
  await check("BLOCK move group scorecard to a group I'm not in", false, () => A.doc("scorecards/s_group").update({ ownerId: "g2" }));
  await check("BLOCK create scorecard for someone else", false, () => C.doc("scorecards/x").set({ ownerType: "person", ownerId: "alice" }));
  await check("BLOCK list all users", false, () => C.collection("users").get());
  await check("BLOCK search users by email", false, () => C.collection("users").where("email", "==", "alice@test.com").get());
  await check("BLOCK edit someone else's profile", false, () => C.doc("users/alice").update({ displayName: "hacked" }));
  await check("BLOCK give myself premium beta", false, () => A.doc("users/alice").update({ premiumBeta: true }));
  await check("BLOCK new profile with premium beta", false, () => as("z").doc("users/z").set({ premiumBeta: true }));
  await check("BLOCK fake my email on profile", false, () => A.doc("users/alice").update({ email: "ceo@company.com" }));
  await check("BLOCK join a group without an invite", false, () => C.doc("game_groups/g1").update({ members: FV.arrayUnion("carol") }));
  await check("BLOCK join with a made-up invite id", false, () => {
    const b = C.batch();
    b.update(C.doc("game_groups/g1"), { members: FV.arrayUnion("carol"), joinedVia: { type: "mail", id: "nope" } });
    return b.commit();
  });
  await check("BLOCK join with invite but not accepting it", false, () => C.doc("game_groups/g1").update({ members: FV.arrayUnion("carol"), joinedVia: { type: "mail", id: "inv1" } }));
  await check("BLOCK join a different group with an invite", false, () => {
    const b = C.batch();
    b.update(C.doc("users/carol/mail/inv1"), { status: "accepted" });
    b.update(C.doc("game_groups/g2"), { members: FV.arrayUnion("carol"), joinedVia: { type: "mail", id: "inv1" } });
    return b.commit();
  });
  await check("BLOCK join and also change the group", false, () => {
    const b = C.batch();
    b.update(C.doc("users/carol/mail/inv1"), { status: "accepted" });
    b.update(C.doc("game_groups/g1"), { members: FV.arrayUnion("carol"), name: "Mine now", joinedVia: { type: "mail", id: "inv1" } });
    return b.commit();
  });
  await check("BLOCK join with a used invite link", false, () => {
    const b = C.batch();
    b.update(C.doc("game_groups/g1"), { members: FV.arrayUnion("carol"), joinedVia: { type: "link", id: "tokUsed" } });
    b.update(C.doc("player_invites/tokUsed"), { usedBy: "carol" });
    return b.commit();
  });
  await check("BLOCK reuse someone's used invite link", false, () => C.doc("player_invites/tokUsed").update({ usedBy: "carol" }));
  await check("BLOCK forge an invite to myself", false, () => C.doc("users/carol/mail/fake").set({ type: "invite_received", groupId: "g1", groupName: "Family", senderUid: "carol", targetUid: "carol", status: "pending" }));
  await check("BLOCK forge an invite as someone else", false, () => C.doc("users/carol/mail/fake").set({ type: "invite_received", groupId: "g1", groupName: "Family", senderUid: "alice", targetUid: "carol", status: "pending" }));
  await check("BLOCK stranger sends notices to someone", false, () => C.collection("users/alice/mail").add(notice("g2", "carol", "kicked out of")));
  await check("BLOCK notice without a group", false, () => C.collection("users/alice/mail").add({ type: "system_notice", senderUid: "carol", message: "spam" }));
  await check("BLOCK notice pretending to be someone else", false, () => B.collection("users/alice/mail").add(notice("g1", "alice")));
  await check("BLOCK member notices someone outside the group", false, () => B.collection("users/carol/mail").add(notice("g1", "bob")));
  await check("BLOCK fake game-result mail", false, () => B.collection("users/alice/mail").add({ type: "new_scorecard", groupId: "g1", senderUid: "bob", title: "x" }));
  await check("BLOCK read someone else's mail", false, () => C.collection("users/alice/mail").get());
  await check("BLOCK change what my mail says", false, () => A.doc("users/alice/mail/m1").update({ message: "edited" }));
  await check("BLOCK member kicks the owner", false, () => B.doc("game_groups/g1").update({ members: ["bob"] }));
  await check("BLOCK member takes ownership", false, () => B.doc("game_groups/g1").update({ owner: "bob" }));
  await check("BLOCK owner gives group to a non-member", false, () => A.doc("game_groups/g1").update({ owner: "carol" }));
  await check("BLOCK member adds someone else to members", false, () => B.doc("game_groups/g1").update({ members: FV.arrayUnion("carol") }));
  await check("BLOCK member deletes group", false, () => B.doc("game_groups/g1").delete());
  await check("BLOCK create group owned by someone else", false, () => C.doc("game_groups/gx").set({ owner: "alice", members: ["alice", "carol"] }));
  await check("BLOCK stranger lists a group's invite links", false, () => C.collection("player_invites").where("groupId", "==", "g1").where("localPlayerId", "==", "local_1").get());
  await check("BLOCK list all invite links", false, () => C.collection("player_invites").get());
  await check("BLOCK create invite link for a group I'm not in", false, () => C.doc("player_invites/t9").set({ groupId: "g1", createdBy: "carol", usedBy: null }));
  await check("BLOCK save template without premium", false, () => A.collection("scorecard_templates").add({ creatorId: "alice" }));
  await check("BLOCK read someone else's template", false, () => C.doc("scorecard_templates/t1").get());
  await check("BLOCK read feedback", false, () => A.doc("feedback/f1").get());
  await check("BLOCK feedback as someone else", false, () => C.collection("feedback").add({ uid: "alice", text: "x" }));
  await check("BLOCK signed-out read", false, () => env.unauthenticatedContext().firestore().doc("users/alice").get());
  await check("BLOCK signed-out write", false, () => env.unauthenticatedContext().firestore().doc("scorecards/z").set({ ownerType: "person", ownerId: "" }));
  await check("BLOCK unknown collection", false, () => A.collection("anything").add({ a: 1 }));

  await env.cleanup();
  const fails = results.filter((r) => r[0] === "FAIL");
  for (const r of results) console.log(r[0], r[1]);
  console.log(`\n${results.length - fails.length}/${results.length} passed`);
  process.exit(fails.length ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(2); });
