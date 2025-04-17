// app.js
require('dotenv').config();
const express = require('express');
const sequelize = require('./config/database');
const healthRoutes = require('./routes/health');
const fileRoutes = require('./routes/file');
const cicdRouter = require('./routes/cicd');

const app = express();
const port = process.env.PORT || 8080;

// Add middleware to parse requests
app.use(express.json({
  verify: (req, res, buf, encoding) => {
    try {
      JSON.parse(buf);
    } catch (e) {
      res.status(400).end();
      throw new Error('Invalid JSON');
    }
  }
}));
app.use(express.urlencoded({ extended: true }));

// Handle unsupported methods for file routes
app.use((req, res, next) => {
  // Handle /v1/file path
  if (req.path === '/v1/file') {
    if (req.method === 'POST') {
      return next(); // Allow POST
    } else if (req.method === 'GET') {
      return res.status(400).end(); // GET returns 400 Bad Request
    } else if (req.method === 'DELETE') {
      // FIXED: DELETE on /v1/file should return 400 Bad Request
      return res.status(400).end();
    } else {
      // All other methods (HEAD, OPTIONS, PUT, PATCH) return 405
      return res.status(405).end();
    }
  } 
  // Handle /v1/file/{id} path
  else if (req.path.match(/^\/v1\/file\/[^\/]+$/)) {
    if (req.method === 'GET' || req.method === 'DELETE') {
      return next(); // Allow GET and DELETE
    } else {
      // FIXED: HEAD, OPTIONS, etc. on /v1/file/{id} should return 405
      return res.status(405).end();
    }
  }
  next();
});

// Routes
app.use('/healthz', healthRoutes);
app.use('/v1/file', fileRoutes);
app.use('/cicd', cicdRouter);

// Error handling middleware
app.use((err, req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).end();
  }
  next();
});

if (process.env.NODE_ENV !== 'test') {
  const bootstrap = async () => {
    try {
      await sequelize.authenticate();
      console.log('Database connection established.');
      await sequelize.sync();
      console.log('Database synchronized.');
      
      app.listen(port, () => {
        console.log(`Server running on port ${port}`);
      });
    } catch (error) {
      console.log('Database connection failed - starting server without database');
      app.listen(port, () => {
        console.log(`Server running on port ${port}`);
      });
    }
  };

  bootstrap();
}

module.exports = app;