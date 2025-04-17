// tests/health.test.js
const request = require('supertest');
const { expect } = require('chai');
process.env.NODE_ENV = 'test';
require('dotenv').config({ path: '.env.test' });

const app = require('../app');
const sequelize = require('../config/database');

describe('Health Check API Tests', function() {
  let server;
  let dbConnected = false;

  before(async function() {
    try {
      await sequelize.authenticate();
      await sequelize.sync();
      dbConnected = true;
      console.log('Database is connected');
    } catch (error) {
      console.log('Database is unavailable');
      dbConnected = false;
    }
    server = app.listen(3000);
  });

  after(async function() {
    if (server) server.close();
    if (dbConnected) await sequelize.close();
  });

  describe('GET /healthz - Database Checks', function() {
    it('should handle database state appropriately', function(done) {
      request(server)
        .get('/healthz')
        .expect('Cache-Control', 'no-cache, no-store, must-revalidate;')
        .expect('Pragma', 'no-cache')
        .expect('X-Content-Type-Options', 'nosniff')
        .expect(dbConnected ? 200 : 503)
        .end(function(err, res) {
          if (err) return done(err);
          expect(res.body).to.be.empty;
          done();
        });
    });
  });

  // Failure scenarios
  describe('GET /healthz - Failure', function() {
    it('should return 400 for request with query parameters', function(done) {
      request(server)
        .get('/healthz?param=value')
        .expect(400)
        .end(done);
    });

    it('should return 400 for request with body', function(done) {
      request(server)
        .get('/healthz')
        .send({ data: 'test' })
        .expect(400)
        .end(done);
    });

    it('should return 400 for request with Content-Type header', function(done) {
      request(server)
        .get('/healthz')
        .set('Content-Type', 'application/json')
        .expect(400)
        .end(done);
    });

    it('should return 400 for request with Content-Length header', function(done) {
      request(server)
        .get('/healthz')
        .set('Content-Length', '0')
        .expect(400)
        .end(done);
    });
  });

  // Method not allowed scenarios
  describe('Invalid HTTP Methods', function() {
    it('should return 405 for POST request', function(done) {
      request(server)
        .post('/healthz')
        .expect(405)
        .end(done);
    });

    it('should return 405 for PUT request', function(done) {
      request(server)
        .put('/healthz')
        .expect(405)
        .end(done);
    });

    it('should return 405 for DELETE request', function(done) {
      request(server)
        .delete('/healthz')
        .expect(405)
        .end(done);
    });

    it('should return 405 for PATCH request', function(done) {
      request(server)
        .patch('/healthz')
        .expect(405)
        .end(done);
    });

    it('should return 405 for HEAD request', function(done) {
      request(server)
        .head('/healthz')
        .expect(405)
        .end(done);
    });
  });
});