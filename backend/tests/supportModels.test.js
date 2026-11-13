const { db, sql, params } = require('./modelHelpers');
const reports = require('../src/models/reportModel');
const feedback = require('../src/models/feedbackModel');

beforeEach(() => jest.resetAllMocks());

describe('reportModel', () => {
  test('is_urgent becomes a real boolean (MariaDB gives 1 / 0)', async () => {
    db.query.mockResolvedValue([{ report_id: 1, is_urgent: 1 }, { report_id: 2, is_urgent: 0 }]);
    expect((await reports.listAll()).map((r) => r.is_urgent)).toEqual([true, false]);
    db.query.mockResolvedValue([{ report_id: 1, is_urgent: 1 }]);
    expect((await reports.findById(1)).is_urgent).toBe(true);
    expect(sql()).toContain('JOIN vehicles');
    expect(sql()).toContain('JOIN users');
  });
  test('findById: missing -> null', async () => {
    db.query.mockResolvedValue([]);
    expect(await reports.findById(1)).toBeNull();
  });
  test('create: urgent flag stored as 1 / 0, optional columns default to null', async () => {
    db.query.mockResolvedValue({ insertId: 5 });
    expect(await reports.create({ user_id: 1, vehicle_id: 2, ride_id: 7, category: 'accident', is_urgent: true, location: 'Gate 2', details: '[URGENT] x' })).toBe(5);
    expect(params()).toEqual([1, 2, 7, 'accident', 1, 'Gate 2', '[URGENT] x']);
    await reports.create({ user_id: 1, vehicle_id: 2, category: 'other' });
    expect(params()).toEqual([1, 2, null, 'other', 0, null, null]);
  });
  test('setStatus sets resolved_at only for "resolved"', async () => {
    await reports.setStatus(5, 'resolved');
    expect(sql()).toContain("resolved_at = IF(? = 'resolved', NOW(), NULL)");
    expect(params()).toEqual(['resolved', 'resolved', 5]);
    await reports.setStatus(5, 'open');
    expect(params()).toEqual(['open', 'open', 5]);
  });
});

describe('feedbackModel', () => {
  test('finders', async () => {
    db.query.mockResolvedValue([{ feedback_id: 1 }]);
    expect(await feedback.findById(1)).toEqual({ feedback_id: 1 });
    await feedback.listAll();
    expect(sql()).toContain('ORDER BY f.created_at DESC');
    db.query.mockResolvedValue([]);
    expect(await feedback.findById(9)).toBeNull();
  });
  test('create / setStatus / countOpen', async () => {
    db.query.mockResolvedValue({ insertId: 4 });
    expect(await feedback.create({ user_id: 1, topic: 'app_bug', message: 'hello' })).toBe(4);
    expect(params()).toEqual([1, 'app_bug', 'hello']);
    await feedback.setStatus(4, 'read');
    expect(params()).toEqual(['read', 4]);
    db.query.mockResolvedValue([{ n: 3 }]);
    expect(await feedback.countOpen()).toBe(3);
    expect(sql()).toContain("status = 'open'");
  });
});
