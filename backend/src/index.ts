import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import authRoutes from "./routes/auth";
import boxesRoutes from "./routes/boxes";
import cardsRoutes from "./routes/cards";
import reviewsRoutes from "./routes/reviews";
import statsRoutes from "./routes/stats";
import importRoutes from "./routes/import";

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// API Routes
app.use("/api/auth", authRoutes);
app.use("/api/boxes", boxesRoutes);
app.use("/api", cardsRoutes);
app.use("/api", reviewsRoutes);
app.use("/api", statsRoutes);
app.use("/api/import", importRoutes);

// Error handling middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error("Error:", err);
  res.status(err.status || 500).json({
    error: err.message || "Internal server error",
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 BrainFood Backend Server running on port ${PORT}`);
  console.log(`📚 Environment: ${process.env.NODE_ENV || "development"}`);
});

