const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.sendInviteNotification = functions.firestore
  .document("users/{userId}/mail/{mailId}")
  .onCreate(async (snap, context) => {
    try {
      const mailData = snap.data();
      const targetUid = context.params.userId; 

      let settingKey = null;
      let title = "Scorecards";
      let body = mailData.message || "";

      if (mailData.type === 'invite_received') {
        settingKey = 'invite_received';
        title = "New Group Invite!";
        body = `${mailData.senderName} invited you to join ${mailData.groupName}.`;
      } 
      else if (mailData.type === 'system_notice') {
        const msg = mailData.message || "";
        
        if (msg.includes("kicked out of")) {
            settingKey = 'removed_from_group';
            title = "Removed from Group";
        } else if (msg.includes("deleted the group")) {
            settingKey = 'group_deleted';
            title = "Group Deleted";
        } else if (msg.includes("added local player")) {
            settingKey = 'new_player_added';
            title = "Player Added";
        } else if (msg.includes("removed local player")) { 
            settingKey = 'player_removed';
            title = "Player Removed";
        } else if (msg.includes("accepted your invite")) { 
            settingKey = 'invite_accepted';
            title = "Invite Accepted";
        } else if (msg.includes("linked to the local profile")) {
            settingKey = 'new_player_linked';
            title = "Player Linked";
        } else if (msg.includes("left the group")) { // NEW MAPPING
            settingKey = 'player_left';
            title = "Player Left";
        } else {
            return null; 
        }
      } 
      else {
        return null;
      }

      const userDoc = await db.collection("users").doc(targetUid).get();
      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return null;

      const settings = userData.notificationSettings || {};
      if (settings[settingKey] === false) {
         console.log(`User opted out of ${settingKey} notifications. Push aborted.`);
         return null; 
      }

      const payload = {
        notification: { 
            title: title, 
            body: body 
        },
        android: { 
            notification: { 
                icon: "notification_icon", 
                color: "#7855C1", 
                tag: settingKey 
            } 
        },
        data: { 
            type: mailData.type,
            mailId: context.params.mailId,
            click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        token: fcmToken,
      };

      return admin.messaging().send(payload);
      
    } catch (e) { 
        console.error("Error sending push:", e);
        return null; 
    }
  });

exports.onScorecardFinalized = functions.firestore
  .document("scorecards/{scorecardId}")
  .onWrite(async (change, context) => {
    const scorecardId = context.params.scorecardId;
    const before = change.before.data();
    const after = change.after.data();

    // If document was deleted, ignore
    if (!after) return null;

    // We only want to trigger exactly when a game gets finalized
    const wasFinalized = before ? before.isFinalized : false;
    const isFinalized = after.isFinalized;

    if (!isFinalized || wasFinalized) {
      return null;
    }

    // It must belong to a group to notify everyone
    if (after.ownerType !== "group" || !after.ownerId) {
      return null;
    }

    const groupId = after.ownerId;
    const groupName = after.groupName || "a group";
    const gameType = after.gameType || "game";
    const playerIds = after.playerIds || [];
    const playerNames = after.playerNames || [];
    const rounds = after.rounds || [];
    const submittedBy = after.submittedBy;

    // 1. Fetch group members
    const groupDoc = await db.collection("game_groups").doc(groupId).get();
    if (!groupDoc.exists) return null;

    const members = groupDoc.data().members || [];
    if (members.length === 0) return null;

    // 2. Safely compute the winners and losers based on Game Type
    let results = [];
    const customSettings = after.customSettings || {};
    const layout = customSettings.layoutSettings || customSettings;
    const isCustomTemplate =
      !!customSettings.layoutSettings || !!customSettings.cellConfigs;
    const lowWins = [
      "lowest_after_rounds",
      "lowest_score",
      "lowest_when_reached_score",
    ].includes(customSettings.winCondition);

    if (isCustomTemplate) {
      // Custom templates store `player_{p}_Score` (or `player_{p}_{i}_Score`
      // when a player has several inputs per round).
      const inputs = parseInt(layout.inputsPerPlayer || "1", 10) || 1;
      for (let p = 0; p < playerNames.length; p++) {
        let tot = 0;
        for (const r of rounds) {
          if (inputs > 1) {
            for (let i = 0; i < inputs; i++) {
              tot += parseInt(r[`player_${p}_${i}_Score`] || "0", 10) || 0;
            }
          } else {
            tot += parseInt(r[`player_${p}_Score`] || "0", 10) || 0;
          }
        }
        results.push({ score: tot, uids: [playerIds[p]] });
      }
    } else if (gameType.toLowerCase() === "spades") {
      const last = rounds.length > 0 ? rounds[rounds.length - 1] : null;
      if (last) {
        results.push({ score: parseInt(last.t1Total || "0", 10), uids: [playerIds[0], playerIds[1]] });
        results.push({ score: parseInt(last.t2Total || "0", 10), uids: [playerIds[2], playerIds[3]] });
      }
    } else if (gameType.toLowerCase() === "wavelength") {
      const teams = Math.floor(playerNames.length / 2);
      for (let t = 0; t < teams; t++) {
        let tot = 0;
        for (let r of rounds) {
          tot += parseInt(r[`t${t + 1}Score`] || "0", 10);
        }
        let uids = [];
        if (t * 2 < playerIds.length) uids.push(playerIds[t * 2]);
        if (t * 2 + 1 < playerIds.length) uids.push(playerIds[t * 2 + 1]);
        results.push({ score: tot, uids });
      }
    } else {
      // Standard / Yahtzee / Poker
      const last = rounds.length > 0 ? rounds[rounds.length - 1] : null;
      for (let i = 0; i < playerNames.length; i++) {
        let tot = 0;
        if (last && last[`p${i + 1}Total`] !== undefined) {
          tot = parseInt(last[`p${i + 1}Total`], 10);
        } else {
          for (let r of rounds) {
            tot += parseInt(r[`p${i + 1}Score`] || "0", 10);
          }
        }
        results.push({ score: tot, uids: [playerIds[i]] });
      }
    }

    // Find the winning score (lowest for "lowest score wins" templates)
    let maxScore = lowWins ? Infinity : -Infinity;
    for (let r of results) {
      if (lowWins ? r.score < maxScore : r.score > maxScore) maxScore = r.score;
    }

    // Distribute UIDs to Winners and Losers arrays
    const winnerUids = [];
    const loserUids = [];
    for (let r of results) {
      const uids = r.uids.filter((u) => !!u); // guests have no uid
      if (r.score === maxScore) {
        winnerUids.push(...uids);
      } else {
        loserUids.push(...uids);
      }
    }

    const batch = db.batch();
    const tokensToMessages = [];

    // 3. Notify each group member according to their result & settings
    for (const uid of members) {
      // Skip sending notification/mail to the person who submitted it
      if (uid === submittedBy) continue;

      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      const settings = userData.notificationSettings || {};

      // Respect the toggle button
      if (settings["new_scorecard_added"] === false) {
        continue;
      }

      const displayName = userData.displayName || "champion";
      let title = `New ${gameType} Scorecard in ${groupName}`;
      let body = `A new ${gameType} scorecard was added!`;

      const isWinner = winnerUids.includes(uid);
      const isLoser = loserUids.includes(uid);
      const isParticipant = isWinner || isLoser;

      // Personalized messaging
      if (isParticipant) {
        if (isWinner) {
          body = `Congratulations on the ${gameType} win, ${displayName}!`;
        } else {
          body = `Looks like you lost that game of ${gameType}. Better luck next time.`;
        }
      } else {
        body = `A new ${gameType} scorecard was added. Looks like you weren't in this one!`;
      }

      // Add to their in-app Mail Inbox
      const mailRef = db.collection("users").doc(uid).collection("mail").doc();
      batch.set(mailRef, {
        id: mailRef.id,
        type: "new_scorecard",
        title: title,
        body: body,
        status: "unread",
        scorecardId: scorecardId,
        groupId: groupId,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      // Queue an actual OS-level Push Notification
      const fcmToken = userData.fcmToken;
      if (fcmToken) {
        tokensToMessages.push({
          token: fcmToken,
          notification: { title, body },
          data: { scorecardId, groupId, type: "new_scorecard" }
        });
      }
    }

    // Commit all Inbox messages
    await batch.commit();

    // Fire off all external push notifications concurrently
    if (tokensToMessages.length > 0) {
      try {
        const sendPromises = tokensToMessages.map(msg => admin.messaging().send(msg));
        await Promise.all(sendPromises);
      } catch (err) {
        console.error("Error sending push notifications:", err);
      }
    }

    return null;
  });

// Optic developer app: new-user alerts and user admin (see optic.js).
Object.assign(exports, require("./optic"));
