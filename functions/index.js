const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
admin.initializeApp();
const db = admin.firestore();

const SPOTIFY_CLIENT_ID = defineSecret("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = defineSecret("SPOTIFY_CLIENT_SECRET");

const GROUP_ID = "peb";
const MADRID_TIME_ZONE = "Europe/Madrid";

// ======================================================
// SPOTIFY
// ======================================================

function extractPlaylistId(inputUrl) {
  if (!inputUrl || typeof inputUrl !== "string") return null;
  const trimmed = inputUrl.trim();

  const uriMatch = trimmed.match(/^spotify:playlist:([a-zA-Z0-9]+)$/);
  if (uriMatch) return uriMatch[1];

  try {
    const url = new URL(trimmed);
    const parts = url.pathname.split("/").filter(Boolean);
    const idx = parts.indexOf("playlist");
    if (idx !== -1 && parts[idx + 1]) return parts[idx + 1];
  } catch (e) {}

  if (/^[a-zA-Z0-9]{10,}$/.test(trimmed)) return trimmed;
  return null;
}

async function getAppToken(clientId, clientSecret) {
  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");

  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`Token error ${res.status}: ${text}`);
  }

  const data = await res.json();
  return data.access_token;
}

async function fetchAllPlaylistTracks(playlistId, token) {
  const tracks = [];
  let url = `https://api.spotify.com/v1/playlists/${playlistId}/tracks?limit=100`;

  while (url) {
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (res.status === 429) {
      const retryAfter = Number(res.headers.get("retry-after") || "1");
      await new Promise((r) => setTimeout(r, Math.max(1, retryAfter) * 1000));
      continue;
    }

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`Spotify API ${res.status}: ${text}`);
    }

    const data = await res.json();

    for (const item of data.items || []) {
      const t = item?.track;
      if (!t || t.is_local) continue;

      const coverUrl =
        t.album?.images?.[0]?.url ||
        t.album?.images?.[1]?.url ||
        t.album?.images?.[2]?.url ||
        "";

      const releaseDate = t.album?.release_date || "";
      const releaseYear = releaseDate
        ? Number(String(releaseDate).slice(0, 4))
        : null;

      tracks.push({
        id: t.id,
        title: t.name,
        artists: (t.artists || []).map((a) => a.name).filter(Boolean),
        spotifyUrl: t.external_urls?.spotify || "",
        coverUrl,
        releaseYear: Number.isFinite(releaseYear) ? releaseYear : null,
      });
    }

    url = data.next;
  }

  return tracks;
}

exports.spotifyGetPlaylistTracks = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET],
  },
  async (request) => {
    const playlistUrl = request.data?.playlistUrl;
    const playlistId = extractPlaylistId(playlistUrl);

    if (!playlistId) {
      throw new HttpsError(
        "invalid-argument",
        "No se pudo extraer el ID de la playlist. Pega un link tipo open.spotify.com/playlist/..."
      );
    }

    try {
      const clientId = SPOTIFY_CLIENT_ID.value();
      const clientSecret = SPOTIFY_CLIENT_SECRET.value();

      const token = await getAppToken(clientId, clientSecret);
      const tracks = await fetchAllPlaylistTracks(playlistId, token);

      return { playlistId, total: tracks.length, tracks };
    } catch (e) {
      throw new HttpsError(
        "internal",
        `No se pudieron cargar canciones: ${e?.message || e}`
      );
    }
  }
);

// ======================================================
// HELPERS FECHA MADRID
// ======================================================

function madridTodayKey() {
  const now = new Date();
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: MADRID_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

function getVisibleFromDate(eventDate) {
  const d = eventDate.toDate ? eventDate.toDate() : new Date(eventDate);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, 0, 0, 0, 0);
}

// ======================================================
// RECORDATORIOS GALA
// ======================================================

exports.sendDailyPendingGalaVoteReminders = onSchedule(
  {
    schedule: "0 10 * * *",
    timeZone: MADRID_TIME_ZONE,
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const todayKey = madridTodayKey();
    const now = new Date();

    const eventsSnap = await db
      .collection("groups")
      .doc(GROUP_ID)
      .collection("events")
      .where("countsForGala", "==", true)
      .get();

    for (const eventDoc of eventsSnap.docs) {
      const eventData = eventDoc.data() || {};
      const participantIds = Array.isArray(eventData.participantIds)
        ? eventData.participantIds
        : [];

      if (!participantIds.length) continue;
      if (!eventData.date) continue;

      const visibleFrom = getVisibleFromDate(eventData.date);
      if (now < visibleFrom) continue;

      const votesSnap = await eventDoc.ref.collection("galaVotes").get();
      const votedProfileIds = new Set(votesSnap.docs.map((d) => d.id));

      const pendingProfileIds = participantIds.filter(
        (profileId) => !votedProfileIds.has(profileId)
      );

      if (!pendingProfileIds.length) continue;

      for (const profileId of pendingProfileIds) {
        const reminderRef = eventDoc.ref
          .collection("galaReminderDailyLog")
          .doc(`${profileId}_${todayKey}`);

        const reminderSnap = await reminderRef.get();
        if (reminderSnap.exists) continue;

        const sessionsSnap = await db
          .collection("groups")
          .doc(GROUP_ID)
          .collection("sessions")
          .where("profileId", "==", profileId)
          .limit(1)
          .get();

        if (sessionsSnap.empty) {
          await reminderRef.set({
            profileId,
            dateKey: todayKey,
            sent: false,
            reason: "no_session",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        const sessionDoc = sessionsSnap.docs[0];
        const sessionData = sessionDoc.data() || {};
        const token = sessionData.fcmToken;

        if (!token || typeof token !== "string" || token.trim().length === 0) {
          await reminderRef.set({
            profileId,
            dateKey: todayKey,
            sent: false,
            reason: "no_token",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        try {
          const messageId = await admin.messaging().send({
            token,
            notification: {
              title: "Tienes votos de gala pendientes",
              body: `Ya puedes votar en ${eventData.name || "la gala"}.`,
            },
            data: {
              type: "gala_vote_pending",
              eventId: eventDoc.id,
            },
          });

          await reminderRef.set({
            profileId,
            dateKey: todayKey,
            sent: true,
            messageId,
            eventId: eventDoc.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (e) {
          const code = e?.code || "";
          const message = e?.message || String(e);

          if (
            code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered"
          ) {
            await sessionDoc.ref.set(
              {
                fcmToken: admin.firestore.FieldValue.delete(),
                fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }

          await reminderRef.set({
            profileId,
            dateKey: todayKey,
            sent: false,
            reason: code || "send_error",
            errorMessage: message,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }

    console.log("Recordatorios diarios de gala procesados");
  }
);

// ======================================================
// DAILY GAMES DESDE FIRESTORE
// ======================================================

function shuffle(array) {
  const copy = [...array];

  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }

  return copy;
}

async function loadDatasetIds(gameId) {
  const snap = await db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("daily_game_datasets")
    .doc(gameId)
    .collection("items")
    .select()
    .get();

  return snap.docs.map((doc) => doc.id);
}

async function ensureGameChallengeFromFirestore(gameId, buildPayload) {
  const dateKey = madridTodayKey();

  const challengeRef = db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("daily_game_challenges")
    .doc(`${gameId}_${dateKey}`);

  const rotationRef = db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("daily_game_rotations")
    .doc(gameId);

  const itemsCol = db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("daily_game_datasets")
    .doc(gameId)
    .collection("items");

  await db.runTransaction(async (tx) => {
    const existingChallenge = await tx.get(challengeRef);

    if (existingChallenge.exists) {
      console.log(`[${gameId}] challenge ya existe para ${dateKey}`);
      return;
    }

    const rotationSnap = await tx.get(rotationRef);

    let remainingIds = [];

    if (rotationSnap.exists) {
      remainingIds = Array.isArray(rotationSnap.data().remainingIds)
        ? rotationSnap.data().remainingIds
        : [];
    }

    if (!remainingIds.length) {
      const allIds = await loadDatasetIds(gameId);

      if (!allIds.length) {
        throw new HttpsError(
          "internal",
          `El dataset de ${gameId} está vacío en Firestore`
        );
      }

      remainingIds = shuffle(allIds);
    }

    const selectedId = remainingIds.shift();

    if (!selectedId) {
      throw new HttpsError(
        "internal",
        `No se pudo seleccionar id para el juego ${gameId}`
      );
    }

    const itemRef = itemsCol.doc(selectedId);
    const itemSnap = await tx.get(itemRef);

    if (!itemSnap.exists) {
      throw new HttpsError(
        "internal",
        `No existe el item ${selectedId} en el dataset ${gameId}`
      );
    }

    const item = {
      id: itemSnap.id,
      ...itemSnap.data(),
    };

    const payload = buildPayload(item);

    if (!payload || typeof payload !== "object") {
      throw new HttpsError(
        "internal",
        `Payload inválido para el juego ${gameId}`
      );
    }

    tx.set(challengeRef, {
      gameId,
      dateKey,
      payload,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(
      rotationRef,
      {
        remainingIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(
      `[${gameId}] challenge creado para ${dateKey} con id ${selectedId}`
    );
  });
}

exports.ensureTodayDailyGames = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const result = {
      ok: true,
      dateKey: madridTodayKey(),
      created: [],
      failed: [],
    };

    const safeEnsure = async (gameId, buildPayload) => {
      try {
        await ensureGameChallengeFromFirestore(gameId, buildPayload);
        result.created.push(gameId);
      } catch (error) {
        console.error(`Error creando challenge de ${gameId}:`, error);
        result.failed.push({
          gameId,
          message: error?.message || String(error),
        });
      }
    };

    // IMPORTANTE:
    // LoLdle y Pokedle siguen enviando SOLO targetId.
    // La app sigue comparando con sus archivos Dart locales.
    await safeEnsure("loldle", (item) => ({
      targetId: item.id,
    }));

    await safeEnsure("pokedle", (item) => ({
      targetId: item.id,
    }));

    await safeEnsure("wordle", (item) => ({
      solution: item.word,
      wordLength: item.wordLength || String(item.word || "").length,
    }));

    await safeEnsure("sudoku", (item) => ({
      puzzle: item.puzzle,
      solution: item.solution,
      difficulty: item.difficulty,
    }));

    await safeEnsure("queens", (item) => ({
      size: item.size,
      regionsRows: item.regionsRows,
      solution: item.solution,
      difficulty: item.difficulty,
    }));

    await safeEnsure("zip", (item) => ({
      size: item.size,
      points: item.points,
      solutionPath: item.solutionPath,
    }));

    await safeEnsure("patches", (item) => ({
      size: item.size,
      pieces: item.pieces,
      solutionRects: item.solutionRects,
    }));

    await safeEnsure("tango", (item) => ({
      size: item.size,
      initialBoardRows: item.initialBoardRows,
      solutionRows: item.solutionRows,
      constraintsJson: item.constraintsJson || "[]",
      difficulty: item.difficulty,
    }));

    result.ok = result.failed.length === 0;
    return result;
  }
);
// ======================================================
// NOTIFICACIONES SOCIAL
// ======================================================

async function getProfileName(profileId) {
  const snap = await db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("profiles")
    .doc(profileId)
    .get();

  return snap.exists ? snap.data().name || "Alguien" : "Alguien";
}

async function sendToProfileSessions({ profileId, notification, data }) {
  const sessionsSnap = await db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("sessions")
    .where("profileId", "==", profileId)
    .get();

  for (const sessionDoc of sessionsSnap.docs) {
    const token = sessionDoc.data().fcmToken;

    if (!token || typeof token !== "string") continue;

    try {
      await admin.messaging().send({
        token,
        notification,
        data,
      });
    } catch (e) {
      const code = e?.code || "";

      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        await sessionDoc.ref.set(
          {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      console.error("Error enviando notificación:", code, e?.message || e);
    }
  }
}

async function sendToAllProfilesExcept({ excludedProfileId, notification, data }) {
  const sessionsSnap = await db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("sessions")
    .get();

  for (const sessionDoc of sessionsSnap.docs) {
    const session = sessionDoc.data() || {};
    const profileId = session.profileId;
    const token = session.fcmToken;

    if (!profileId || profileId === excludedProfileId) continue;
    if (!token || typeof token !== "string") continue;

    try {
      await admin.messaging().send({
        token,
        notification,
        data,
      });
    } catch (e) {
      const code = e?.code || "";

      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        await sessionDoc.ref.set(
          {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      console.error("Error enviando notificación global:", code, e?.message || e);
    }
  }
}

exports.notifyNewSocialPost = onDocumentCreated(
  {
    document: "groups/peb/social_posts/{postId}",
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const authorId = post.authorId;
    if (!authorId) return;

    const authorName = await getProfileName(authorId);

    const body =
      post.text && String(post.text).trim().length > 0
        ? String(post.text).trim().slice(0, 120)
        : post.mediaType === "image"
          ? "Ha subido una imagen"
          : post.mediaType === "video"
            ? "Ha subido un vídeo"
            : post.mediaType === "gif"
              ? "Ha subido un GIF"
              : "Ha publicado algo nuevo";

    await sendToAllProfilesExcept({
      excludedProfileId: authorId,
      notification: {
        title: `${authorName} ha publicado en el muro`,
        body,
      },
      data: {
        type: "social_post",
        postId: event.params.postId,
        authorId,
      },
    });
  }
);

exports.notifyNewPrivateMessage = onDocumentCreated(
  {
    document: "groups/peb/private_chats/{chatId}/messages/{messageId}",
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const senderId = msg.senderId;
    const chatId = event.params.chatId;

    if (!senderId || !chatId) return;

    const chatSnap = await db
      .collection("groups")
      .doc(GROUP_ID)
      .collection("private_chats")
      .doc(chatId)
      .get();

    if (!chatSnap.exists) return;

    const participantIds = Array.isArray(chatSnap.data().participantIds)
      ? chatSnap.data().participantIds
      : [];

    const receiverIds = participantIds.filter((id) => id !== senderId);
    if (!receiverIds.length) return;

    const senderName = await getProfileName(senderId);

    const body =
      msg.text && String(msg.text).trim().length > 0
        ? String(msg.text).trim().slice(0, 120)
        : msg.mediaType === "image"
          ? "📷 Imagen"
          : msg.mediaType === "video"
            ? "🎥 Vídeo"
            : msg.mediaType === "gif"
              ? "🖼️ GIF"
              : "Nuevo mensaje";

    for (const receiverId of receiverIds) {
      await sendToProfileSessions({
        profileId: receiverId,
        notification: {
          title: senderName,
          body,
        },
        data: {
          type: "private_message",
          chatId,
          senderId,
          messageId: event.params.messageId,
        },
      });
    }
  }
);