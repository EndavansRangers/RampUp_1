const { Pool } = require('pg');
const request = require('supertest');
const server = require('./server');

// Configure environment variables for testing
process.env.PGUSER = process.env.PGUSER || 'tunefy_user';
process.env.PGHOST = process.env.PGHOST || 'localhost';
process.env.PGDB = process.env.PGDB || 'tunefy';
process.env.PGPASS = process.env.PGPASS || 'tunefy_pass';
process.env.PGPORT = process.env.PGPORT || '5432';
process.env.NODE_ENV = 'test';

const TEST_SESSION_ID = 'test-session-123';

describe('Tunefy Backend API Tests', () => {

    describe('Health Check', () => {
        it('should return healthy status', async () => {
            const response = await request(server)
                .get('/health')
                .expect(200);

            expect(response.body).toHaveProperty('status', 'healthy');
            expect(response.body).toHaveProperty('service', 'tunefy-backend');
        });
    });

    describe('POST /add-song', () => {
        it('should add a song successfully', async () => {
            // Clear database first
            await request(server).post('/clear-database').expect(200);

            const songData = {
                artist_name: 'Test Artist',
                song_name: 'Test Song',
                user_id: 'test-user-1',
                session_id: TEST_SESSION_ID
            };

            const response = await request(server)
                .post('/add-song')
                .send(songData)
                .expect(201);

            expect(response.body).toHaveProperty('song_name', songData.song_name);
            expect(response.body).toHaveProperty('artist_name', songData.artist_name);
            expect(response.body).toHaveProperty('session_id', TEST_SESSION_ID);
        });

        it('should fail when session_id is missing', async () => {
            const songData = {
                artist_name: 'Test Artist',
                song_name: 'Test Song',
                user_id: 'test-user-1'
            };

            const response = await request(server)
                .post('/add-song')
                .send(songData)
                .expect(400);

            expect(response.body).toHaveProperty('error');
        });
    });

    describe('GET /playlist', () => {
        it('should return empty playlist for new session', async () => {
            // Clear database first
            await request(server).post('/clear-database').expect(200);

            const response = await request(server)
                .get(`/playlist?sessionId=${TEST_SESSION_ID}`)
                .expect(200);

            expect(response.body).toEqual([]);
        });

        it('should fail when sessionId is missing', async () => {
            const response = await request(server)
                .get('/playlist')
                .expect(400);

            expect(response.body).toHaveProperty('error', 'Session ID is required');
        });
    });

    describe('POST /clear-database', () => {
        it('should clear database successfully', async () => {
            const response = await request(server)
                .post('/clear-database')
                .expect(200);

            expect(response.body).toHaveProperty('message', 'Database cleared');
        });
    });
});