const admin = require("firebase-admin");

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "pebapp-dfc40",
});
// IMPORTA AQUÍ TUS ARRAYS ACTUALES
// OJO: estos arrays deben estar exportados desde otro archivo, por ejemplo daily_datasets.js
const {
  WORDLE_WORDS,
  TANGO_PUZZLES,
  LOL_CHAMPIONS,
  POKEMON_GEN123,
  QUEENS_PUZZLES,
  SUDOKU_PUZZLES,
  ZIP_PUZZLES,
  PATCHES_PUZZLES,
} = require("./daily_datasets");


const db = admin.firestore();

const GROUP_ID = "peb";
const BATCH_LIMIT = 400;

function normalizeId(value) {
  return String(value)
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_\-]/g, "");
}

async function uploadDataset(gameId, items, mapper) {
  console.log(`\nSubiendo dataset: ${gameId}`);
  console.log(`Total elementos: ${items.length}`);

  const itemsRef = db
    .collection("groups")
    .doc(GROUP_ID)
    .collection("daily_game_datasets")
    .doc(gameId)
    .collection("items");

  let batch = db.batch();
  let count = 0;
  let batchCount = 0;

  for (const rawItem of items) {
    const mapped = mapper(rawItem);

    if (!mapped.id) {
      throw new Error(`Elemento sin id en ${gameId}: ${JSON.stringify(rawItem)}`);
    }

    const docId = normalizeId(mapped.id);

    const docRef = itemsRef.doc(docId);

    batch.set(
      docRef,
      {
        ...mapped,
        id: docId,
        gameId,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    count++;
    batchCount++;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      console.log(`Subidos ${count}/${items.length} de ${gameId}`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`Dataset ${gameId} subido correctamente`);
}

async function main() {
  await uploadDataset(
    "wordle",
    WORDLE_WORDS,
    (word) => ({
      id: word,
      word: String(word).toLowerCase().trim(),
      wordLength: String(word).trim().length,
    })
  );

  await uploadDataset(
    "loldle",
    LOL_CHAMPIONS,
    (item) => ({
      ...item,
      id: item.id,
    })
  );

  await uploadDataset(
    "pokedle",
    POKEMON_GEN123,
    (item) => ({
      ...item,
      id: item.id,
    })
  );

  await uploadDataset(
    "sudoku",
    SUDOKU_PUZZLES,
    (item, index) => ({
      id: item.id || `sudoku_${index}`,
      puzzle: item.puzzle,
      solution: item.solution,
      difficulty: item.difficulty || "normal",
    })
  );

await uploadDataset(
  "queens",
  QUEENS_PUZZLES,
  (item, index) => ({
    id: item.id || `queens_${index}`,
    size: item.size,

    // Firestore no permite arrays dentro de arrays.
    // Guardamos cada fila como string.
    regionsRows: item.regions.map((row) => row.join(",")),

    // Si solution es array simple, esto vale.
    solution: item.solution,

    difficulty: item.difficulty || "normal",
  })
);

  await uploadDataset(
    "zip",
    ZIP_PUZZLES,
    (item, index) => ({
      id: item.id || `zip_${index}`,
      size: item.size,
      points: item.points,
      solutionPath: item.solutionPath,
    })
  );

  await uploadDataset(
    "patches",
    PATCHES_PUZZLES,
    (item, index) => ({
      id: item.id || `patches_${index}`,
      size: item.size,
      pieces: item.pieces,
      solutionRects: item.solutionRects,
    })
  );

  await uploadDataset(
  "tango",
  TANGO_PUZZLES,
  (item, index) => ({
    id: item.id || `tango_${index}`,
    size: item.size,

    // Firestore no permite arrays dentro de arrays
    initialBoardRows: item.initialBoard.map((row) =>
      row.map((cell) => (cell === null ? "_" : String(cell))).join(",")
    ),

    solutionRows: item.solution.map((row) => row.join(",")),

    // Si constraints también tuviera arrays dentro, lo guardamos como JSON seguro
    constraintsJson: JSON.stringify(item.constraints || []),

    difficulty: item.difficulty || "normal",
  })
);

  console.log("\nTodos los datasets se han subido correctamente.");
  process.exit(0);
}

main().catch((error) => {
  console.error("Error subiendo datasets:", error);
  process.exit(1);
});