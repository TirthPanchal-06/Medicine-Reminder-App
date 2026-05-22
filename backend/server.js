require('dotenv').config();
const app = require('./src/app');
const { startScheduler } = require('./src/utils/scheduler');

const connectDB = async () => {
  try {
    const connect = require('./src/config/db');
    await connect();
  } catch (error) {
    console.error('Failed to load database config:', error.message);
  }
};

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  // Connect to Database
  await connectDB();

  // Start background reminder scheduler
  startScheduler();

  // Listen on PORT
  const server = app.listen(PORT, () => {
    console.log(`Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
  });

  // Handle unhandled promise rejections gracefully
  process.on('unhandledRejection', (err, promise) => {
    console.error(`Unhandled Promise Rejection: ${err.message}`);
    // Close server & exit process
    server.close(() => process.exit(1));
  });
};

startServer();
