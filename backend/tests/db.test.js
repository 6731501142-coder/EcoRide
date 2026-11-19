// db.js with mysql2 mocked: query returns the rows, withConnection always releases, pool options are right
jest.mock('mysql2/promise');

let db, pool, mysql;
beforeEach(() => {
  pool = { query: jest.fn(), getConnection: jest.fn(), end: jest.fn().mockResolvedValue() };
  // fresh copy of db.js (and of the mocked mysql2) for every test, so the cached pool does not leak between tests
  jest.isolateModules(() => {
    mysql = require('mysql2/promise');
    mysql.createPool.mockReturnValue(pool);
    db = require('../src/db');
  });
});

test('pool is created once, with the settings the app needs', () => {
  db.getPool();
  db.getPool();
  expect(mysql.createPool).toHaveBeenCalledTimes(1);
  expect(mysql.createPool.mock.calls[0][0]).toMatchObject({ dateStrings: true, decimalNumbers: true, charset: 'utf8mb4' });
});

test('query returns only the rows', async () => {
  pool.query.mockResolvedValue([[{ a: 1 }], ['fields']]);
  expect(await db.query('SELECT 1', [5])).toEqual([{ a: 1 }]);
  expect(pool.query).toHaveBeenCalledWith('SELECT 1', [5]);
});

test('withConnection releases the connection after success and after an error', async () => {
  const conn = { release: jest.fn() };
  pool.getConnection.mockResolvedValue(conn);
  expect(await db.withConnection(async () => 'ok')).toBe('ok');
  expect(conn.release).toHaveBeenCalledTimes(1);
  await expect(db.withConnection(async () => { throw new Error('boom'); })).rejects.toThrow('boom');
  expect(conn.release).toHaveBeenCalledTimes(2);
});

test('close ends the pool and a later call builds a new one', async () => {
  db.getPool();
  await db.close();
  expect(pool.end).toHaveBeenCalled();
  db.getPool();
  expect(mysql.createPool).toHaveBeenCalledTimes(2);
  await db.close();
  await db.close(); // closing twice is harmless
});
