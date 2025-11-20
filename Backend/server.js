const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const bodyParser = require('body-parser');
const multer = require('multer');
const pdfParse = require('pdf-parse');
const { v4: uuid } = require('uuid');
const path = require('path');
const fs = require('fs');

const { calculateNext, createInitialScheduling, defaultConfig } = require('./fsrs');
const store = require('./storage');

const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
const upload = multer({ dest: uploadDir });
const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

const requireContext = (req, res, next) => {
  const userId = req.header('x-user-id') || req.query.userId;
  const boxId = req.header('x-box-id') || req.query.boxId;
  req.userId = userId;
  req.boxId = boxId;
  next();
};

const authorizeToken = (req, res, next) => {
  const bearer = req.header('authorization');
  const tokenParam = req.query.token;
  const token = bearer?.replace(/^Bearer\s+/i, '') || tokenParam;
  if (!token) {
    req.tokenAuthenticated = false;
    return next();
  }
  const found = store.findToken(token);
  if (!found) return res.status(401).json({ error: 'token_invalid_or_expired' });
  req.userId = found.userId;
  req.boxId = found.boxId;
  req.tokenAuthenticated = true;
  next();
};

const requireAuth = (req, res, next) => {
  if (!req.tokenAuthenticated) {
    return res.status(401).json({ error: 'authentication_required' });
  }
  next();
};

app.get('/health', (_req, res) => {
  const db = store.read();
  res.json({
    ok: true,
    fsrs: defaultConfig,
    users: db.users.length,
    boxes: db.boxes.length,
    cards: db.cards.length,
  });
});

app.post('/auth/register', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) return res.status(400).json({ error: 'name_email_password_required' });
  const db = store.read();
  if (db.users.find((u) => u.email === email)) {
    return res.status(400).json({ error: 'email_exists' });
  }
  const passwordHash = await bcrypt.hash(password, 10);
  const user = { id: uuid(), name, email, passwordHash, createdAt: new Date() };
  store.appendUser(user);
  const token = uuid();
  const expiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000); // 12h session
  store.upsertToken({ token, userId: user.id, boxId: null, expiresAt });
  res.status(201).json({ user: { id: user.id, name: user.name, email: user.email }, token, expiresAt });
});

app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'email_and_password_required' });
  const db = store.read();
  const user = db.users.find((u) => u.email === email);
  if (!user) return res.status(401).json({ error: 'invalid_credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash || '');
  if (!ok) return res.status(401).json({ error: 'invalid_credentials' });
  const token = uuid();
  const expiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000);
  store.upsertToken({ token, userId: user.id, boxId: null, expiresAt });
  res.json({ user: { id: user.id, name: user.name, email: user.email }, token, expiresAt });
});

app.post('/users/:userId/boxes', authorizeToken, requireAuth, (req, res) => {
  const { userId } = req.params;
  if (req.userId !== userId) return res.status(403).json({ error: 'forbidden' });
  const { name } = req.body;
  if (!name) return res.status(400).json({ error: 'name_required' });
  const box = { id: uuid(), userId, name, createdAt: new Date() };
  store.appendBox(box);
  res.status(201).json(box);
});

app.get('/users/:userId/boxes', authorizeToken, requireAuth, (req, res) => {
  const { userId } = req.params;
  if (req.userId !== userId) return res.status(403).json({ error: 'forbidden' });
  const db = store.read();
  res.json(db.boxes.filter((b) => b.userId === userId));
});

app.post('/tokens', (req, res) => {
  const { userId, boxId, ttlMinutes = 20 } = req.body;
  if (!userId || !boxId) return res.status(400).json({ error: 'userId_and_boxId_required' });
  const token = uuid();
  const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);
  store.upsertToken({ token, userId, boxId, expiresAt });
  res.status(201).json({ token, userId, boxId, expiresAt });
});

app.get('/cards', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { dueOnly } = req.query;
  const { userId, boxId } = req;
  if (!userId || !boxId) return res.status(400).json({ error: 'userId_and_boxId_required' });
  const { cards } = store.read();
  const scoped = cards.filter((c) => c.userId === userId && c.boxId === boxId);
  const now = new Date();
  const payload = dueOnly === 'true' || dueOnly === true
    ? scoped.filter((c) => new Date(c.due) <= now)
    : scoped;
  res.json(payload);
});

app.get('/cards/:id', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { userId, boxId } = req;
  const { cards } = store.read();
  const card = cards.find((c) => c.id === req.params.id && c.userId === userId && c.boxId === boxId);
  if (!card) return res.status(404).json({ error: 'not_found' });
  res.json(card);
});

app.post('/cards', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { front, back, tags = [], boxId: bodyBox } = req.body;
  const boxId = bodyBox || req.boxId;
  const userId = req.userId;
  if (!userId || !boxId) return res.status(400).json({ error: 'userId_and_boxId_required' });
  if (!front || !back) return res.status(400).json({ error: 'front_and_back_required' });
  const scheduling = createInitialScheduling(new Date());
  const card = {
    id: uuid(),
    userId,
    boxId,
    front,
    back,
    tags,
    ...scheduling,
    history: [],
    createdAt: new Date(),
    updatedAt: new Date()
  };
  store.appendCard(card);
  res.status(201).json(card);
});

app.post('/cards/batch', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { cards = [] } = req.body;
  const userId = req.userId;
  const boxId = req.boxId;
  if (!userId || !boxId) return res.status(400).json({ error: 'userId_and_boxId_required' });
  if (!Array.isArray(cards)) return res.status(400).json({ error: 'cards_must_be_array' });
  const now = new Date();
  const created = cards.map((item) => {
    const scheduling = createInitialScheduling(now);
    const card = {
      id: uuid(),
      userId,
      boxId,
      front: item.front,
      back: item.back,
      tags: item.tags || [],
      ...scheduling,
      history: [],
      createdAt: now,
      updatedAt: now
    };
    store.appendCard(card);
    return card;
  });
  res.status(201).json(created);
});

app.put('/cards/:id', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { front, back, tags } = req.body;
  const { userId, boxId } = req;
  const updated = store.updateCard(req.params.id, (card) => {
    if (card.userId !== userId || card.boxId !== boxId) return card;
    return {
      ...card,
      front: front ?? card.front,
      back: back ?? card.back,
      tags: tags ?? card.tags,
      updatedAt: new Date()
    };
  });
  if (!updated || updated.userId !== userId || updated.boxId !== boxId) return res.status(404).json({ error: 'not_found' });
  res.json(updated);
});

app.delete('/cards/:id', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { userId, boxId } = req;
  const db = store.read();
  const card = db.cards.find((c) => c.id === req.params.id && c.userId === userId && c.boxId === boxId);
  if (!card) return res.status(404).json({ error: 'not_found' });
  store.deleteCard(req.params.id);
  res.status(204).send();
});

app.post('/review', authorizeToken, requireAuth, requireContext, (req, res) => {
  const { cardId, rating } = req.body;
  const { userId, boxId } = req;
  if (![1, 2, 3, 4].includes(rating)) {
    return res.status(400).json({ error: 'rating_must_be_1_to_4' });
  }
  const updated = store.updateCard(cardId, (card) => {
    if (card.userId !== userId || card.boxId !== boxId) return card;
    const next = calculateNext(card, rating, new Date());
    return {
      ...card,
      ...next,
      history: [
        ...(card.history || []),
        { rating, reviewedAt: new Date(), intervalDays: next.intervalDays }
      ],
      updatedAt: new Date()
    };
  });
  if (!updated || updated.userId !== userId || updated.boxId !== boxId) return res.status(404).json({ error: 'not_found' });
  res.json(updated);
});

app.post('/import/pdf', authorizeToken, requireAuth, requireContext, upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'file_required' });
  const { delimiter = '\n' } = req.body;
  const buffer = fs.readFileSync(req.file.path);
  try {
    const data = await pdfParse(buffer);
    const lines = data.text
      .split(delimiter)
      .map((s) => s.trim())
      .filter(Boolean);
    const now = new Date();
    const created = lines.map((line) => {
      const scheduling = createInitialScheduling(now);
      const card = {
        id: uuid(),
        userId: req.userId,
        boxId: req.boxId,
        front: line,
        back: '',
        tags: ['pdf-import'],
        ...scheduling,
        history: [],
        createdAt: now,
        updatedAt: now
      };
      store.appendCard(card);
      return card;
    });
    res.status(201).json({ count: created.length, cards: created });
  } catch (err) {
    res.status(500).json({ error: 'pdf_parse_failed', details: err.message });
  } finally {
    fs.unlink(req.file.path, () => {});
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_server_error' });
});

app.listen(PORT, () => {
  console.log(`BrainFood backend listening on ${PORT}`);
});
