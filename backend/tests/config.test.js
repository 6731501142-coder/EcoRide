// JWT_SECRET ต้องปลอดภัย ไม่งั้น server ไม่ยอมรัน (src/server.js)
const { jwtSecretProblem, MIN_SECRET_LENGTH } = require('../src/config');

describe('jwtSecretProblem', () => {
  test('missing secret is rejected', () => {
    expect(jwtSecretProblem('')).toBe('JWT_SECRET is not set');
    expect(jwtSecretProblem(undefined)).toBe('JWT_SECRET is not set');
  });
  test('example / default values are rejected', () => {
    expect(jwtSecretProblem('dev-secret-change-me')).toBe('JWT_SECRET is still the example value');
    expect(jwtSecretProblem('change-me-to-a-long-random-text')).toBe('JWT_SECRET is still the example value');
  });
  test('short secrets are rejected', () => {
    expect(jwtSecretProblem('abc123')).toMatch(/too short/);
    expect(jwtSecretProblem('x'.repeat(MIN_SECRET_LENGTH - 1))).toMatch(/too short/);
  });
  test('a long random secret is accepted', () => {
    expect(jwtSecretProblem('x'.repeat(MIN_SECRET_LENGTH))).toBeNull();
    expect(jwtSecretProblem(require('crypto').randomBytes(32).toString('hex'))).toBeNull();
  });
});
