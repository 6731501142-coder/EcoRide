const { db, sql, params } = require('./modelHelpers');
const m = require('../src/models/catalogModel');

beforeEach(() => jest.resetAllMocks());

test('listTypes / findType', async () => {
  db.query.mockResolvedValue([{ type_id: 1 }]);
  expect(await m.listTypes()).toEqual([{ type_id: 1 }]);
  expect(sql()).toContain('FROM vehicle_types');
  expect(await m.findType(1)).toEqual({ type_id: 1 });
  expect(params()).toEqual([1]);
  db.query.mockResolvedValue([]);
  expect(await m.findType(9)).toBeNull();
});

test('plans: only active ones are offered', async () => {
  db.query.mockResolvedValue([{ plan_id: 1 }]);
  expect(await m.listPlans()).toEqual([{ plan_id: 1 }]);
  expect(sql()).toContain('WHERE is_active = 1');
  expect(await m.findPlan(1)).toEqual({ plan_id: 1 });
  expect(sql()).toContain('plan_id = ? AND is_active = 1');
  db.query.mockResolvedValue([]);
  expect(await m.findPlan(9)).toBeNull();
});
