const { db, sql, params } = require('./modelHelpers');
const m = require('../src/models/userModel');

beforeEach(() => jest.resetAllMocks());

describe('finders', () => {
  test('findById never selects password_hash', async () => {
    db.query.mockResolvedValue([{ user_id: 1 }]);
    expect(await m.findById(1)).toEqual({ user_id: 1 });
    expect(sql()).toContain('FROM users WHERE user_id = ?');
    expect(sql()).not.toContain('password_hash');
    expect(sql()).not.toContain('SELECT *');
    expect(params()).toEqual([1]);
  });
  test('no row -> null', async () => {
    db.query.mockResolvedValue([]);
    expect(await m.findById(9)).toBeNull();
    expect(await m.findByUsername('x')).toBeNull();
    expect(await m.findByStudentId('x')).toBeNull();
    expect(await m.findByUsernameWithHash('x')).toBeNull();
  });
  test('login lookup is case-insensitive and includes the hash', async () => {
    db.query.mockResolvedValue([{ user_id: 1, password_hash: 'h' }]);
    expect((await m.findByUsernameWithHash('Somchai.J')).password_hash).toBe('h');
    expect(sql()).toContain('SELECT *');
    expect(sql()).toContain('LOWER(username) = LOWER(?)');
    expect(params()).toEqual(['Somchai.J']);
  });
  test('findByUsername is case-insensitive, no hash', async () => {
    db.query.mockResolvedValue([{ user_id: 1 }]);
    await m.findByUsername('A');
    expect(sql()).toContain('LOWER(username) = LOWER(?)');
    expect(sql()).not.toContain('password_hash');
  });
  test('findByStudentId', async () => {
    db.query.mockResolvedValue([{ user_id: 1 }]);
    await m.findByStudentId('6731501118');
    expect(sql()).toContain('student_id = ?');
    expect(params()).toEqual(['6731501118']);
  });
  test('getPasswordHash returns the hash or null', async () => {
    db.query.mockResolvedValue([{ password_hash: 'abc' }]);
    expect(await m.getPasswordHash(1)).toBe('abc');
    db.query.mockResolvedValue([]);
    expect(await m.getPasswordHash(1)).toBeNull();
  });
});

describe('uniqueness checks', () => {
  test('usernameTaken: true when a row exists, ignores my own id', async () => {
    db.query.mockResolvedValue([{ 1: 1 }]);
    expect(await m.usernameTaken('a', 5)).toBe(true);
    expect(sql()).toContain('user_id <> ?');
    expect(params()).toEqual(['a', 5]);
    db.query.mockResolvedValue([]);
    expect(await m.usernameTaken('a')).toBe(false);
    expect(params()).toEqual(['a', 0]);
  });
  test('studentIdTaken', async () => {
    db.query.mockResolvedValue([{ 1: 1 }]);
    expect(await m.studentIdTaken('1', 3)).toBe(true);
    expect(params()).toEqual(['1', 3]);
    db.query.mockResolvedValue([]);
    expect(await m.studentIdTaken('1')).toBe(false);
  });
});

describe('writes', () => {
  test('create: always a student with 0 credit; returns the new id', async () => {
    db.query.mockResolvedValue({ insertId: 12 });
    const id = await m.create({ student_id: '1', username: 'u', full_name: 'N', password_hash: 'h' });
    expect(id).toBe(12);
    expect(sql()).toContain("'student', 0");
    expect(params()).toEqual(['1', 'u', 'N', 'h']);
  });
  test('updateProfile', async () => {
    await m.updateProfile(3, { full_name: 'N', student_id: 'S', username: 'u' });
    expect(sql()).toContain('UPDATE users SET full_name = ?, student_id = ?, username = ? WHERE user_id = ?');
    expect(params()).toEqual(['N', 'S', 'u', 3]);
  });
  test('updateNames (admin) does not touch the username', async () => {
    await m.updateNames(3, { full_name: 'N', student_id: 'S' });
    expect(sql()).not.toContain('username');
    expect(params()).toEqual(['N', 'S', 3]);
  });
  test('updatePassword', async () => {
    await m.updatePassword(3, 'hash');
    expect(sql()).toContain('SET password_hash = ?');
    expect(params()).toEqual(['hash', 3]);
  });
  test('setAvatar: only one kind at a time', async () => {
    await m.setAvatar(3, { avatar_id: 5 });
    expect(params()).toEqual([5, null, 3]);
    await m.setAvatar(3, { avatar_url: '/uploads/a.png' });
    expect(params()).toEqual([null, '/uploads/a.png', 3]);
    await m.setAvatar(3, {});
    expect(params()).toEqual([null, null, 3]);
  });
  test('setActive stores 1 / 0', async () => {
    await m.setActive(3, true);
    expect(params()).toEqual([1, 3]);
    await m.setActive(3, false);
    expect(params()).toEqual([0, 3]);
  });
});

describe('listStudents', () => {
  test('no search: students only, sorted by name, no LIKE', async () => {
    db.query.mockResolvedValue([{ user_id: 1 }]);
    expect(await m.listStudents()).toEqual([{ user_id: 1 }]);
    expect(sql()).toContain("role = 'student'");
    expect(sql()).toContain('ORDER BY full_name');
    expect(sql()).not.toContain('LIKE');
    expect(sql()).toContain('AS riding');
    expect(params()).toEqual([]);
  });
  test('search: name / username / student id, LIKE wildcards escaped', async () => {
    await m.listStudents(' 50%_a ');
    expect(sql()).toContain('full_name LIKE ? OR username LIKE ? OR student_id LIKE ?');
    expect(params()).toEqual(['%50\\%\\_a%', '%50\\%\\_a%', '%50\\%\\_a%']);
  });
  test('blank search = no filter', async () => {
    await m.listStudents('   ');
    expect(sql()).not.toContain('LIKE');
  });
});
