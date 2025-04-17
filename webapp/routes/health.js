// routes/health.js
const express = require('express');
const router = express.Router();
const HealthCheck = require('../models/healthCheck');
const { logRequest, logError } = require('../config/logger');
const metricsCollector = require('../config/metrics');

const setHeaders = (req, res, next) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate;');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  next();
};

const checkPayload = (req, res, next) => {
  const startTime = Date.now();
  let errorMessage = null;

  // Check query parameters
  if (req.query && Object.keys(req.query).length > 0) {
    errorMessage = "Request contains query parameters";
  }
  // Check body
  else if (req.body && Object.keys(req.body).length > 0) {
    errorMessage = "Request contains body payload";
  }
  // Check content-length header
  else if (req.headers['content-length'] !== undefined) {
    errorMessage = "Request contains Content-Length header";
  }
  // Check for Content-Type header (indicates potential payload)
  else if (req.headers['content-type']) {
    errorMessage = "Request contains Content-Type header";
  }

  // If any error was found, log it and return 400
  if (errorMessage) {
    const error = new Error(errorMessage);
    logError(error, 'Health Check - Bad Request');
    
    // Track the API call with error status
    metricsCollector.trackAPICall('HealthCheck', Date.now() - startTime, 'error');
    
    return res.status(400).end();
  }

  next();
};

// Place this before the GET route to handle all non-GET methods
router.all('/', setHeaders, (req, res, next) => {
  if (req.method !== 'GET') {
    // Log the method not allowed error
    const error = new Error(`Method ${req.method} not allowed on health endpoint`);
    logError(error, 'Health Check - Method Not Allowed');
    
    // Track the API call with error status
    metricsCollector.trackAPICall('HealthCheck', 0, 'error');
    
    return res.status(405).end();
  }
  next();
});

router.get('/', setHeaders, checkPayload, async (req, res) => {
  const startTime = Date.now(); // Add start time tracking

  try {
    // Database record creation with performance tracking
    const dbStartTime = Date.now();
    await HealthCheck.create({
      datetime: new Date()
    });
    const dbDuration = Date.now() - dbStartTime;
    
    // Track database query performance
    await metricsCollector.trackDatabaseQuery('HealthCheckCreation', dbDuration);

    res.status(200).end();

    // Log request and track API metrics
    logRequest(req, res, 'Health Check', startTime);
    await metricsCollector.trackAPICall('HealthCheck', Date.now() - startTime);
  } catch (error) {
    // Comprehensive error logging
    logError(error, 'Health Check');
    await metricsCollector.trackAPICall('HealthCheck', Date.now() - startTime, 'error');
    res.status(503).end();
  }
});

module.exports = router;