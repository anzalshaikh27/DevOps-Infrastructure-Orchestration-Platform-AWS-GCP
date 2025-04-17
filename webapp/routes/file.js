// routes/file.js - Updated with error logging for all status codes
const express = require('express');
const router = express.Router();
const multer = require('multer');
const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { v4: uuidv4 } = require('uuid');
const File = require('../models/file');
const { logRequest, logError } = require('../config/logger');
const metricsCollector = require('../config/metrics');

// Configure multer for memory storage
const storage = multer.memoryStorage();

// Initialize S3 client - will use IAM role automatically in EC2
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const bucketName = process.env.S3_BUCKET;
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
}).single('file');

// Helper function to log errors with status codes
function logStatusError(status, message, route, startTime) {
  const error = new Error(message);
  logError(error, route);
  metricsCollector.trackAPICall(route.replace(/\s+/g, ''), Date.now() - startTime, 'error');
}

// POST /v1/file - Upload a file
router.post('/', (req, res, next) => {
  // Use multer middleware as a function
  upload(req, res, async function(err) {
    const startTime = Date.now();
    
    // Handle multer errors (including multiple files)
    if (err) {
      logError(err, 'File Upload');
      await metricsCollector.trackAPICall('FileUpload', Date.now() - startTime, 'error');
      return res.status(400).end();
    }
    
    // No file uploaded
    if (!req.file) {
      logStatusError(400, 'No file provided', 'File Upload', startTime);
      return res.status(400).end();
    }
    
    try {
      const file = req.file;
      const fileId = uuidv4();
      const key = `${fileId}-${file.originalname}`;

      // Continue with your existing S3 upload logic
      const s3StartTime = Date.now();
      const command = new PutObjectCommand({
        Bucket: bucketName,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        Metadata: {
          fileName: file.originalname,
          fileId: fileId
        }
      });

      await s3Client.send(command);
      const s3Duration = Date.now() - s3StartTime;
      await metricsCollector.trackS3Operation('FileUpload', s3Duration);

      // Save metadata to database - same as your existing code
      const fileRecord = await File.create({
        id: fileId,
        file_name: file.originalname,
        s3_object_key: key,
        size: file.size,
        file_type: file.mimetype
      });

      res.status(201).json({
        id: fileRecord.id,
        file_name: fileRecord.file_name,
        file_type: fileRecord.file_type,
        size: fileRecord.size,
        created_date: fileRecord.created_date
      });

      // Log request and track API metrics
      logRequest(req, res, 'File Upload', startTime);
      await metricsCollector.trackAPICall('FileUpload', Date.now() - startTime);
    } catch (error) {
      logError(error, 'File Upload');
      await metricsCollector.trackAPICall('FileUpload', Date.now() - startTime, 'error');
      res.status(500).end();
    }
  });
});

// GET /v1/file/{id} - Get file by ID
router.get('/:id', async (req, res) => {
  const startTime = Date.now(); // Add start time tracking

  try {
    const fileId = req.params.id;
    
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(fileId)) {
      logStatusError(400, `Invalid UUID format: ${fileId}`, 'File Retrieve', startTime);
      return res.status(400).end(); // Invalid UUID format
    }
    
    // Get file metadata from database
    const fileRecord = await File.findByPk(fileId);
    
    if (!fileRecord) {
      logStatusError(404, `File not found with ID: ${fileId}`, 'File Retrieve', startTime);
      return res.status(404).end();
    }

    // Return file metadata with S3 path
    const response = {
      id: fileRecord.id,
      file_name: fileRecord.file_name,
      s3_object_key: fileRecord.s3_object_key,
      size: fileRecord.size,
      file_type: fileRecord.file_type,
      created_date: fileRecord.created_date,
      s3_path: `s3://${bucketName}/${fileRecord.s3_object_key}`
    };

    res.status(200).json(response);

    // Log request and track API metrics
    logRequest(req, res, 'File Retrieve', startTime);
    await metricsCollector.trackAPICall('FileRetrieve', Date.now() - startTime);
  } catch (error) {
    logError(error, 'File Retrieve');
    await metricsCollector.trackAPICall('FileRetrieve', Date.now() - startTime, 'error');
    res.status(500).end();
  }
});

// DELETE /v1/file/{id} - Delete file by ID
router.delete('/:id', async (req, res) => {
  const startTime = Date.now(); // Add start time tracking

  try {
    const fileId = req.params.id;
    
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(fileId)) {
      logStatusError(401, `Invalid UUID format: ${fileId}`, 'File Delete', startTime);
      return res.status(401).end(); // Invalid UUID format
    }
    
    // Get file metadata from database
    const fileRecord = await File.findByPk(fileId);
    
    if (!fileRecord) {
      logStatusError(404, `File not found with ID: ${fileId}`, 'File Delete', startTime);
      return res.status(404).end();
    }

    // S3 delete with metrics
    const s3StartTime = Date.now();
    const command = new DeleteObjectCommand({
      Bucket: bucketName,
      Key: fileRecord.s3_object_key
    });
    
    await s3Client.send(command);
    const s3Duration = Date.now() - s3StartTime;
    await metricsCollector.trackS3Operation('FileDelete', s3Duration);
    
    // Delete from database
    await fileRecord.destroy();
    
    res.status(204).end();

    // Log request and track API metrics
    logRequest(req, res, 'File Delete', startTime);
    await metricsCollector.trackAPICall('FileDelete', Date.now() - startTime);
  } catch (error) {
    logError(error, 'File Delete');
    await metricsCollector.trackAPICall('FileDelete', Date.now() - startTime, 'error');
    res.status(500).end();
  }
});

// Handle missing ID for DELETE
router.delete('/', (req, res) => {
  const startTime = Date.now();
  logStatusError(404, 'No file ID provided for deletion', 'File Delete', startTime);
  return res.status(404).end();
});

// Add a route handler for base path to prevent HTML error responses
router.get('/', (req, res) => {
  const startTime = Date.now();
  logStatusError(400, 'GET on base path not allowed', 'File Retrieve Base', startTime);
  res.status(400).end();
});

module.exports = router;