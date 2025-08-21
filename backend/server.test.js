// import pkg from 'pg';
const { Pool } = require('pg');
const request = require('supertest');
// Import the server.js file
const server = require('./server');
// Mock the environment variables
process.env.PGUSER = 'your_username';
process.env.PGHOST = 'localhost';
process.env.PGDATABASE = 'your_database_name';
process.env.PGPASSWORD = 'your_password';
process.env.PGPORT = '5432';

// describe('server.js', () => {
//     test('should create a new Pool instance with correct configuration', () => {

//         // Assert that a new Pool instance is created with the correct configuration
//         expect(Pool).toHaveBeenCalledWith({
//             user: process.env.PGUSER,
//             host: process.env.PGHOST,
//             database: process.env.PGDATABASE,
//             password: process.env.PGPASSWORD,
//             port: 5432,
//         });
//     });
// });

describe('POST /add-song', () => {
    it('should insert a new song and verify it with GET /playlist', async () => {

        await request(server)
            .post('/clear-database')
            .expect(200);

        const songData = {
            artist_name: 'Test Artist',
            id: 1,
            popularity: 99,
            song_name: 'Test Song',
            user_id: '1',
            votes: 0,
        };

        // Hacer una solicitud POST a /add-song
        await request(server)
            .post('/add-song')
            .send(songData)
            .expect(201); // Asegúrate de que tu servidor responde con el código de estado correcto

        // Hacer una solicitud GET a /playlist
        const response = await request(server)
            .get('/playlist')
            .expect(200); // Asegúrate de que tu servidor responde con el código de estado correcto

        // Verificar que la canción se agregó a la lista de reproducción
        expect(response.body).toEqual([songData]);

        await request(server)
            .post('/clear-database')
            .expect(200);
    });
});