const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Trigger on CREATE — new task assigned
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

// Trigger on UPDATE — builder added, quote sent, task denied, task revised
exports.onTaskUpdated = onDocumentUpdated("tasks/{taskId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const taskId = event.params.taskId;

  console.log("🔄 onTaskUpdated fired for taskId:", taskId);
  console.log("📋 taskType:", after.taskType);

  // ── Quote notification: fires on project task whenever quote is sent/resent
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

  // ── Builder assignment notification ───────────────────────────────────────
  const newlyAssigned = afterBuilderIds.filter(id => !beforeBuilderIds.includes(id));
  if (newlyAssigned.length > 0) {
    console.log("🔔 New builders assigned:", newlyAssigned);
    await notifyRecipients(newlyAssigned, "New Task Assigned", after.taskName, taskId);
  }

  // ── Task denied → notify project owner ────────────────────────────────────
  if (beforeStatus !== "unassigned" && afterStatus === "unassigned" && after.ownerId) {
    console.log("🔔 Task denied — notifying project owner:", after.ownerId);
    await notifyRecipients(
      [after.ownerId],
      "Task Denied",
      `A builder has denied the task: "${after.taskName}". Please reassign it.`,
      taskId
    );
  }

  // ── Task revised → notify project owner ───────────────────────────────────
  if (beforeStatus !== "revising" && afterStatus === "revising" && after.ownerId) {
    console.log("🔔 Task revised — notifying project owner:", after.ownerId);
    await notifyRecipients(
      [after.ownerId],
      "Revision Requested",
      `A builder has requested a revision for: "${after.taskName}". Please review it.`,
      taskId
    );
  }

  // ── Task accepted → notify project owner ──────────────────────────────────
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

// Shared helper
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

      // Always write the in-app alert regardless of push result
      await getFirestore()
        .collection("alerts")
        .doc(recipientId)
        .collection("items")
        .add({
          title,
          description: body,
          type: "info",
          isRead: false,
          taskId: taskId,  // ← added
          createdAt: new Date(),
        });
      console.log("✅ Alert written for:", recipientId);

    } catch (err) {
      console.error("❌ Error for recipient", recipientId, err);
    }
  }
}