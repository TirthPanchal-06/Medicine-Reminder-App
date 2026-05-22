const express = require('express');
const cors = require('cors');
const path = require('path');

// Route imports
const authRoutes = require('./routes/authRoutes');
const medicineRoutes = require('./routes/medicineRoutes');
const doseRoutes = require('./routes/doseRoutes');
const healthRecordRoutes = require('./routes/healthRecordRoutes');
const familyRoutes = require('./routes/familyRoutes');
const sosRoutes = require('./routes/sosRoutes');
const appointmentRoutes = require('./routes/appointmentRoutes');
const ocrRoutes = require('./routes/ocrRoutes');
const chatRoutes = require('./routes/chatRoutes');
const pushRoutes = require('./routes/pushRoutes');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static uploads serving
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date() });
});

// Route registration
app.use('/api/auth', authRoutes);
app.use('/api/medicines', medicineRoutes);
app.use('/api/doses', doseRoutes);
app.use('/api/push', pushRoutes);
app.use('/api/health-records', healthRecordRoutes);
app.use('/api/family', familyRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/ocr', ocrRoutes);
app.use('/api/chat', chatRoutes);

// Generic error handling middleware
app.use((err, req, res, next) => {
  console.error('[Error Middleware]:', err.stack || err.message);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

module.exports = app;
