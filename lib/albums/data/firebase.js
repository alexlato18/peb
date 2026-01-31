const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteMediaAsGod = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Not logged in.");
  }

  const { eventId, photoId, storagePath } = data || {};
  if (!eventId || !photoId || !storagePath) {
    throw new functions.https.HttpsError("invalid-argument", "Missing parameters.");
  }

  const uid = context.auth.uid;

  // Comprueba rol DIOS en sessions
  const sessionRef = admin.firestore().doc(`groups/peb/sessions/${uid}`);
  const sessionSnap = await sessionRef.get();
  const role = sessionSnap.exists ? sessionSnap.data().role : null;

  if (role !== "DIOS") {
    throw new functions.https.HttpsError("permission-denied", "Only DIOS can do this.");
  }

  const db = admin.firestore();
  const eventRef = db.doc(`groups/peb/events/${eventId}`);
  const photoRef = eventRef.collection("photos").doc(photoId);

  // Borra Storage
  await admin.storage().bucket().file(storagePath).delete({ ignoreNotFound: true });

  // Borra Firestore doc
  await photoRef.delete();

  // Actualiza contador
  await eventRef.update({
    photoCount: admin.firestore.FieldValue.increment(-1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});
