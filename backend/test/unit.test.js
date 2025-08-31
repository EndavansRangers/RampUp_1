const request = require('supertest');
jest.mock('pg', () => {
  const mClient = { connect: jest.fn(), query: jest.fn().mockResolvedValue({ rows: [{ '?column?': 1 }] }), release: jest.fn() };
  return { Pool: jest.fn(() => ({ connect: jest.fn().mockResolvedValue(mClient) })) };
});
const app = require('../server.cjs'); 

describe('GET /health', () => {
  it('returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
  });
});
