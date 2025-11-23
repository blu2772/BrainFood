import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import authRoutes from "./routes/auth";
import boxesRoutes from "./routes/boxes";
import cardsRoutes from "./routes/cards";
import reviewsRoutes from "./routes/reviews";
import statsRoutes from "./routes/stats";
import importRoutes from "./routes/import";
import importStreamRoutes from "./routes/importStream";
import apiKeysRoutes from "./routes/apiKeys";

// Lade Umgebungsvariablen
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());

// Body Parser mit erhöhten Limits
// WICHTIG: express.urlencoded wird nur auf application/x-www-form-urlencoded angewendet
// Für multipart/form-data (File-Uploads) wird Multer verwendet, nicht diese Parser
app.use(express.json({ limit: "50mb" })); // Erhöhtes Limit für große Dateien

// urlencoded nur auf application/x-www-form-urlencoded anwenden (nicht auf multipart/form-data)
app.use((req, res, next) => {
  if (req.is("application/x-www-form-urlencoded")) {
    express.urlencoded({ extended: true, limit: "50mb", parameterLimit: 50000 })(req, res, next);
  } else {
    next();
  }
});

// Wichtig: Multer verarbeitet multipart/form-data, nicht json/urlencoded
// Für File-Uploads wird Multer verwendet, das sein eigenes Limit hat (20 MB)

// Health Check
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Database Health Check
app.get("/health/db", async (req, res) => {
  try {
    const { PrismaClient } = await import("@prisma/client");
    const prisma = new PrismaClient();
    await prisma.$connect();
    await prisma.$disconnect();
    res.json({ status: "ok", database: "connected" });
  } catch (error: any) {
    res.status(500).json({ 
      status: "error", 
      database: "disconnected",
      error: error.message 
    });
  }
});

// API Routes
app.use("/api/auth", authRoutes);
app.use("/api/api-keys", apiKeysRoutes);
app.use("/api/boxes", boxesRoutes);
app.use("/api", cardsRoutes);
app.use("/api", reviewsRoutes);
app.use("/api", statsRoutes);
app.use("/api/import", importRoutes);
app.use("/api/import", importStreamRoutes);

// Error Handling Middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error("Error:", err);
  res.status(err.status || 500).json({
    error: err.message || "Internal server error",
  });
});

// Start Server
app.listen(PORT, () => {
  console.log(`🚀 BrainFood Backend Server running on port ${PORT}`);
  console.log(`📚 Environment: ${process.env.NODE_ENV || "development"}`);
});

