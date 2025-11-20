const express = require('express');
const cors = require('cors');
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

app.get('/health', (_req, res) => {
  res.json({ ok: true, fsrs: defaultConfig, cards: store.read().cards.length });
});

app.get('/cards', (req, res) => {
  const { dueOnly } = req.query;
  const { cards } = store.read();
  const now = new Date();
  const payload =
    dueOnly === 'true'
      ? cards.filter((c) => new Date(c.due) <= now)
      : cards;
  res.json(payload);
});

app.get('/cards/:id', (req, res) => {
  const { cards } = store.read();
  const card = cards.find((c) => c.id === req.params.id);
  if (!card) return res.status(404).json({ error: 'not_found' });
  res.json(card);
});

app.post('/cards', (req, res) => {
  const { front, back, tags = [] } = req.body;
  if (!front || !back) return res.status(400).json({ error: 'front_and_back_required' });
  const scheduling = createInitialScheduling(new Date());
  const card = {
    id: uuid(),
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

app.post('/cards/batch', (req, res) => {
  const { cards = [] } = req.body;
  if (!Array.isArray(cards)) return res.status(400).json({ error: 'cards_must_be_array' });
  const now = new Date();
  const created = cards.map((item) => {
    const scheduling = createInitialScheduling(now);
    const card = {
      id: uuid(),
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

app.put('/cards/:id', (req, res) => {
  const { front, back, tags } = req.body;
  const updated = store.updateCard(req.params.id, (card) => ({
    ...card,
    front: front ?? card.front,
    back: back ?? card.back,
    tags: tags ?? card.tags,
    updatedAt: new Date()
  }));
  if (!updated) return res.status(404).json({ error: 'not_found' });
  res.json(updated);
});

app.delete('/cards/:id', (req, res) => {
  const ok = store.deleteCard(req.params.id);
  if (!ok) return res.status(404).json({ error: 'not_found' });
  res.status(204).send();
});

app.post('/review', (req, res) => {
  const { cardId, rating } = req.body;
  if (![1, 2, 3, 4].includes(rating)) {
    return res.status(400).json({ error: 'rating_must_be_1_to_4' });
  }
  const updated = store.updateCard(cardId, (card) => {
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
  if (!updated) return res.status(404).json({ error: 'not_found' });
  res.json(updated);
});

app.post('/import/pdf', upload.single('file'), async (req, res) => {
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
