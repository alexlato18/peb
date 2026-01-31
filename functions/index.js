const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Guardamos ambos como secret para hacerlo simple y 100% seguro:
const SPOTIFY_CLIENT_ID = defineSecret("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = defineSecret("SPOTIFY_CLIENT_SECRET");

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
  } catch {}

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
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });

    // Si Spotify limita (429), espera y reintenta
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
      const releaseYear = releaseDate ? Number(String(releaseDate).slice(0, 4)) : null;

      tracks.push({
        id: t.id,
        title: t.name,
        artists: (t.artists || []).map((a) => a.name).filter(Boolean),
        spotifyUrl: t.external_urls?.spotify || "",
        coverUrl,
        releaseYear: Number.isFinite(releaseYear) ? releaseYear : null,
      });
    }

    url = data.next; // null => fin
  }

  return tracks;
}

exports.spotifyGetPlaylistTracks = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET], // <-- clave
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
      throw new HttpsError("internal", `No se pudieron cargar canciones: ${e?.message || e}`);
    }
  }
);
