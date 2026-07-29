const http = require('http');
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const connectDB = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const commentRoutes = require('./routes/commentRoutes');
const errorHandler = require('./middleware/errorHandler');
const { initWebSocket } = require('./websocket/wsHandler');

const app = express();
const server = http.createServer(app);

// Initialize WebSocket
initWebSocket(server);

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/comments', commentRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Nested Comments API Server is running smoothly' });
});

// Global Error Handler Middleware
app.use(errorHandler);

// Start Server & Connect Database
const PORT = process.env.PORT || 5000;

if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, async () => {
    console.log(`[Server] Running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
    console.log(`[WebSocket] Server initialized on ws://localhost:${PORT}`);
    
    try {
      await connectDB();
    } catch (err) {
      console.warn(`[Database Warning] Server running on port ${PORT}, but MongoDB is offline.`);
    }
  });
}

module.exports = { app, server };
