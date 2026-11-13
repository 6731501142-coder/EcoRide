// helpers for the model unit tests: db.js is mocked, so we only check the SQL text, its parameters
// and how the rows are turned into return values (the real SQL is exercised by the API / DB tests)
jest.mock('../src/db');
const db = require('../src/db');

const lastCall = () => db.query.mock.calls[db.query.mock.calls.length - 1];
const sql = () => lastCall()[0].replace(/\s+/g, ' ').trim();
const params = () => lastCall()[1];

/** a fake connection for db.withConnection: queries are answered in order */
function fakeConnection(answers = []) {
  const conn = { query: jest.fn() };
  answers.forEach((a) => conn.query.mockResolvedValueOnce(a));
  db.withConnection.mockImplementation(async (fn) => fn(conn));
  return conn;
}

module.exports = { db, sql, params, fakeConnection };
