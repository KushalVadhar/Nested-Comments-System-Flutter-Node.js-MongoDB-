const mongoose = require('mongoose');
const dns = require('dns');

// Resolve DNS SRV lookup issues on Windows Node.js for MongoDB Atlas
try {
  if (dns.setDefaultResultOrder) {
    dns.setDefaultResultOrder('ipv4first');
  }
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  // Ignore if custom DNS set is restricted
}

// Disable buffering so queries fail immediately when MongoDB is offline rather than hanging for 10 seconds
mongoose.set('bufferCommands', false);

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/nested_comments_db');
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`MongoDB Connection Error: ${error.message}`);
    console.warn(`[Database] Ensure MongoDB service is running locally at mongodb://localhost:27017 or set MONGODB_URI in .env`);
  }
};

module.exports = connectDB;
