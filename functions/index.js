const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// Task triggers
// ─────────────────────────────────────────────────────────────────────────────

exports.onTaskAssigned = onDocumentCreated("tasks/{taskId}", async (event) => {
  const task = event.data.data();
  const taskId = event.params.taskId;
  console.log("🔔 onTaskAssigned triggered for taskId:", taskId);

  if (task.taskType !== "task") {
    console.log("⚠️ Not a task, skipping.");
    return;
  }

  const recipientIds = task.assignedBuilderIds ?? [];
  if (recipientIds.length === 0) {
    console.log("⚠️ No assignedBuilderIds found, skipping.");
    return;
  }

  await notifyRecipients(recipientIds, "New Task Assigned", task.taskName, taskId);
});

exports.onTaskUpdated = onDocumentUpdated("tasks/{taskId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const taskId = event.params.taskId;

  console.log("🔄 onTaskUpdated fired for taskId:", taskId);
  console.log("📋 taskType:", after.taskType);

  // ── Quote notification ────────────────────────────────────────────────────
  if (after.taskType === "project") {
    const beforeSentAt = before.quoteLastSentAt?.toMillis?.() ?? null;
    const afterSentAt = after.quoteLastSentAt?.toMillis?.() ?? null;
    const quoteWasSent = afterSentAt !== beforeSentAt && afterSentAt !== null;

    if (quoteWasSent && after.quoteLastSentTo) {
      console.log("🔔 Quote sent/resent to:", after.quoteLastSentTo);
      await notifyRecipients(
        [after.quoteLastSentTo],
        "You've Received a Quote",
        `A builder has sent you a quote for: ${after.taskName ?? "a project"}`,
        taskId
      );
    }
    return;
  }

  if (after.taskType !== "task") return;

  const beforeStatus = before.status ?? "";
  const afterStatus = after.status ?? "";
  const beforeBuilderIds = before.assignedBuilderIds ?? [];
  const afterBuilderIds = after.assignedBuilderIds ?? [];

  // ── Builder assignment ────────────────────────────────────────────────────
  const newlyAssigned = afterBuilderIds.filter(id => !beforeBuilderIds.includes(id));
  if (newlyAssigned.length > 0) {
    console.log("🔔 New builders assigned:", newlyAssigned);
    await notifyRecipients(newlyAssigned, "New Task Assigned", after.taskName, taskId);
  }

  // ── Task denied ───────────────────────────────────────────────────────────
  if (beforeStatus !== "unassigned" && afterStatus === "unassigned" && after.ownerId) {
    console.log("🔔 Task denied — notifying project owner:", after.ownerId);
    await notifyRecipients(
      [after.ownerId],
      "Task Denied",
      `A builder has denied the task: "${after.taskName}". Please reassign it.`,
      taskId
    );
  }

  // ── Task revised ──────────────────────────────────────────────────────────
  if (beforeStatus !== "revising" && afterStatus === "revising" && after.ownerId) {
    console.log("🔔 Task revised — notifying project owner:", after.ownerId);
    await notifyRecipients(
      [after.ownerId],
      "Revision Requested",
      `A builder has requested a revision for: "${after.taskName}". Please review it.`,
      taskId
    );
  }

  // ── Task accepted ─────────────────────────────────────────────────────────
  if (beforeStatus !== "active" && afterStatus === "active" && after.ownerId) {
    console.log("🔔 Task accepted — notifying project owner:", after.ownerId);
    await notifyRecipients(
      [after.ownerId],
      "Task Accepted",
      `A builder has accepted the task: "${after.taskName}".`,
      taskId
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Chat trigger
// ─────────────────────────────────────────────────────────────────────────────

exports.onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;

    console.log("💬 onChatMessageCreated fired — chatId:", chatId, "messageId:", messageId);

    const senderId = message.senderId;
    if (!senderId) {
      console.log("⚠️ No senderId on message, skipping.");
      return;
    }

    const chatDoc = await getFirestore().collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      console.log("⚠️ Chat doc not found:", chatId);
      return;
    }

    const chatData = chatDoc.data();
    const participants = chatData.participants ?? [];
    const participantNames = chatData.participantNames ?? {};

    const recipientIds = participants.filter(id => id !== senderId);
    if (recipientIds.length === 0) {
      console.log("⚠️ No recipients to notify.");
      return;
    }

    const senderName = participantNames[senderId] ?? "Someone";
    const isImage = message.type === "image";
    const notifBody = isImage
      ? `${senderName} sent a photo`
      : `${senderName}: ${_truncate(message.text ?? "", 80)}`;

    console.log(`🔔 Notifying ${recipientIds.length} recipient(s) — body: "${notifBody}"`);

    for (const recipientId of recipientIds) {
      const unreadCount = chatData.unreadCount?.[recipientId] ?? 0;
      if (unreadCount === 0) {
        console.log(`ℹ️ ${recipientId} has chat open (unread=0), skipping push.`);
      }

      try {
        const userDoc = await getFirestore()
          .collection("users")
          .doc(recipientId)
          .get();

        if (!userDoc.exists) {
          console.log("⚠️ User not found:", recipientId);
          continue;
        }

        const token = userDoc.data()?.fcmToken;
        console.log(`📱 FCM token for ${recipientId}:`, token ?? "NOT FOUND");

        // ── Push notification (only if unread) ────────────────────────────────
        if (token && unreadCount > 0) {
          try {
            await getMessaging().send({
              token,
              notification: {
                title: senderName,
                body: isImage ? "📷 Photo" : _truncate(message.text ?? "", 80),
              },
              data: {
                type: "chat",
                chatId,
                senderId,
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    "content-available": 1,
                  },
                },
              },
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channelId: "chat_messages",
                },
              },
            });
            console.log("✅ Chat push sent to:", recipientId);
          } catch (fcmErr) {
            if (
              fcmErr.errorInfo?.code === "messaging/registration-token-not-registered" ||
              fcmErr.errorInfo?.code === "messaging/invalid-registration-token"
            ) {
              console.log("🗑️ Stale FCM token removed for:", recipientId);
              await getFirestore()
                .collection("users")
                .doc(recipientId)
                .update({ fcmToken: null });
            } else {
              console.error("❌ FCM send error for:", recipientId, fcmErr);
            }
          }
        }

        // ── In-app alert (always written) ─────────────────────────────────────
        await getFirestore()
          .collection("alerts")
          .doc(recipientId)
          .collection("items")
          .add({
            title: senderName,
            description: isImage ? "Sent you a photo" : _truncate(message.text ?? "", 120),
            type: "chat",
            isRead: false,
            chatId,
            createdAt: new Date(),
          });
        console.log("✅ Chat alert written for:", recipientId);

      } catch (err) {
        console.error("❌ Error for recipient", recipientId, err);
      }
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

async function notifyRecipients(recipientIds, title, body, taskId) {
  for (const recipientId of recipientIds) {
    try {
      const userDoc = await getFirestore().collection("users").doc(recipientId).get();
      if (!userDoc.exists) {
        console.log("⚠️ User not found:", recipientId);
        continue;
      }

      const token = userDoc.data()?.fcmToken;
      console.log(`📱 FCM token for ${recipientId}:`, token ?? "NOT FOUND");

      if (token) {
        try {
          await getMessaging().send({
            token,
            notification: { title, body },
            data: { taskId },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  "content-available": 1,
                },
              },
            },
            android: {
              priority: "high",
              notification: {
                sound: "default",
                channelId: "alerts",
              },
            },
          });
          console.log("✅ Push sent to:", recipientId);
        } catch (fcmErr) {
          if (
            fcmErr.errorInfo?.code === "messaging/registration-token-not-registered" ||
            fcmErr.errorInfo?.code === "messaging/invalid-registration-token"
          ) {
            console.log("🗑️ Stale FCM token removed for:", recipientId);
            await getFirestore()
              .collection("users")
              .doc(recipientId)
              .update({ fcmToken: null });
          } else {
            console.error("❌ FCM send error for:", recipientId, fcmErr);
          }
        }
      }

      // Always write the in-app alert
      await getFirestore()
        .collection("alerts")
        .doc(recipientId)
        .collection("items")
        .add({
          title,
          description: body,
          type: "info",
          isRead: false,
          taskId,
          createdAt: new Date(),
        });
      console.log("✅ Alert written for:", recipientId);

    } catch (err) {
      console.error("❌ Error for recipient", recipientId, err);
    }
  }
}

function _truncate(str, maxLen) {
  if (str.length <= maxLen) return str;
  return str.substring(0, maxLen).trimEnd() + "…";
}