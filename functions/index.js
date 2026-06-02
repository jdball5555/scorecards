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