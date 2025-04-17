const winston = require('winston');
const fs = require('fs');
const path = require('path');

const logDirectory = process.env.LOG_DIR || '/var/log/webapp';

if (!fs.existsSync(logDirectory)) {
  try {
    fs.mkdirSync(logDirectory, { recursive: true });
    fs.chmodSync(logDirectory, 0o755);
  } catch (error) {
    console.error('Could not create log directory:', error);
  }
}

// This formats and returns false for error logs
const errorFilter = winston.format((info) => {
  return info.level !== 'error' ? info : false;
});

// Info logger without console transport
const appLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    errorFilter(), // MUST come first to filter errors
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message, ...metadata }) => {
      return `${timestamp} [${level}]: ${message} ${
        Object.keys(metadata).length ? JSON.stringify(metadata) : ''
      }`;
    })
  ),
  transports: [
    // Remove console transport
    new winston.transports.File({
      filename: path.join(logDirectory, 'application.log')
    })
  ]
});

// Error logger without console transport
const errorLogger = winston.createLogger({
  level: 'error',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message, ...metadata }) => {
      return `${timestamp} [${level}]: ${message} ${
        Object.keys(metadata).length ? JSON.stringify(metadata) : ''
      }`;
    })
  ),
  transports: [
    // Remove console transport
    new winston.transports.File({
      filename: path.join(logDirectory, 'error.log')
    })
  ]
});

function logRequest(req, res, route, startTime) {
  const responseTime = Date.now() - startTime;
  appLogger.info(`Successfully processed ${route} request`, {
    method: req.method,
    path: req.path,
    statusCode: res.statusCode,
    responseTime: `${responseTime}ms`,
    timestamp: new Date().toISOString()
  });
}

function logError(error, route) {
  errorLogger.error(`Failed to process ${route} request due to an error`, {
    message: error.message,
    stack: error.stack,
    timestamp: new Date().toISOString()
  });
}

// Export logger
const logger = {
  info: (message, meta) => appLogger.info(message, meta),
  warn: (message, meta) => appLogger.warn(message, meta),
  debug: (message, meta) => appLogger.debug(message, meta),
  error: (message, meta) => errorLogger.error(message, meta)
};

module.exports = {
  logger,
  logRequest,
  logError
};