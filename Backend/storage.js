const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'data', 'cards.json');

const ensureDb = () => {
  if (!fs.existsSync(path.dirname(DB_PATH))) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  }
  if (!fs.existsSync(DB_PATH)) {
    fs.writeFileSync(
      DB_PATH,
      JSON.stringify({ users: [], boxes: [], cards: [], tokens: [] }, null, 2)
    );
  } else {
    // Migrate legacy structure that only had cards
    const raw = fs.readFileSync(DB_PATH, 'utf-8');
    try {
      const parsed = JSON.parse(raw);
      if (!parsed.users) {
        parsed.users = [];
        parsed.boxes = [];
        parsed.tokens = [];
        fs.writeFileSync(DB_PATH, JSON.stringify(parsed, null, 2));
      }
    } catch (err) {
      // If parse failed, reset to a known-good empty shape
      fs.writeFileSync(
        DB_PATH,
        JSON.stringify({ users: [], boxes: [], cards: [], tokens: [] }, null, 2)
      );
    }
  }
};

const read = () => {
  ensureDb();
  const raw = fs.readFileSync(DB_PATH, 'utf-8');
  return JSON.parse(raw);
};

const write = (data) => {
  ensureDb();
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2));
};

const appendCard = (card) => {
  const db = read();
  db.cards.push(card);
  write(db);
  return card;
};

const updateCard = (id, updater) => {
  const db = read();
  const idx = db.cards.findIndex((c) => c.id === id);
  if (idx === -1) return null;
  db.cards[idx] = updater(db.cards[idx]);
  write(db);
  return db.cards[idx];
};

const deleteCard = (id) => {
  const db = read();
  const idx = db.cards.findIndex((c) => c.id === id);
  if (idx === -1) return false;
  db.cards.splice(idx, 1);
  write(db);
  return true;
};

const appendUser = (user) => {
  const db = read();
  db.users.push(user);
  write(db);
  return user;
};

const appendBox = (box) => {
  const db = read();
  db.boxes.push(box);
  write(db);
  return box;
};

const upsertToken = (token) => {
  const db = read();
  db.tokens = db.tokens.filter((t) => t.token !== token.token);
  db.tokens.push(token);
  write(db);
  return token;
};

const findToken = (token) => {
  const db = read();
  const now = Date.now();
  return db.tokens.find((t) => t.token === token && new Date(t.expiresAt).getTime() > now);
};

module.exports = {
  read,
  write,
  appendCard,
  updateCard,
  deleteCard,
  appendUser,
  appendBox,
  upsertToken,
  findToken
};
