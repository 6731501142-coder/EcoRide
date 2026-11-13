const { db, sql, params } = require('./modelHelpers');
const m = require('../src/models/vehicleModel');

beforeEach(() => jest.resetAllMocks());

test('the shared SELECT gives batteryService what it needs', async () => {
  db.query.mockResolvedValue([]);
  await m.listAll();
  expect(sql()).toContain('seconds_since_battery_update');
  expect(sql()).toContain('ride_battery_start');
  expect(sql()).toContain('ride_used_seconds');
  expect(sql()).toContain("r.status IN ('active','overdue')");
  expect(sql()).toContain('LEFT JOIN stations');
  expect(sql()).toContain('ORDER BY v.vehicle_code');
});

test('findById / findByCode: row or null', async () => {
  db.query.mockResolvedValue([{ vehicle_id: 1 }]);
  expect(await m.findById(1)).toEqual({ vehicle_id: 1 });
  expect(sql()).toContain('WHERE v.vehicle_id = ?');
  db.query.mockResolvedValue([]);
  expect(await m.findById(1)).toBeNull();
  expect(await m.findByCode('x')).toBeNull();
});

test('findByCode trims and ignores case', async () => {
  db.query.mockResolvedValue([{ vehicle_id: 1 }]);
  await m.findByCode('  eb-012 ');
  expect(sql()).toContain('UPPER(v.vehicle_code) = UPPER(?)');
  expect(params()).toEqual(['eb-012']);
});

test('listAtStation / listDocked', async () => {
  db.query.mockResolvedValue([]);
  await m.listAtStation(3);
  expect(sql()).toContain('WHERE v.current_station_id = ?');
  expect(params()).toEqual([3]);
  await m.listDocked();
  expect(sql()).toContain('current_station_id IS NOT NULL');
});

test('codeExists', async () => {
  db.query.mockResolvedValue([{ 1: 1 }]);
  expect(await m.codeExists('EB-012')).toBe(true);
  db.query.mockResolvedValue([]);
  expect(await m.codeExists('EB-999')).toBe(false);
});

test('create: new vehicle starts available with a full battery', async () => {
  db.query.mockResolvedValue({ insertId: 11 });
  expect(await m.create({ vehicle_code: 'EB-077', type_id: 1, station_id: 2 })).toBe(11);
  expect(sql()).toContain("100, 'available'");
  expect(params()).toEqual(['EB-077', 1, 2]);
});

test('saveBattery restarts the charging clock', async () => {
  await m.saveBattery(5, 63);
  expect(sql()).toContain('battery_updated_at = NOW()');
  expect(params()).toEqual([63, 5]);
});

test('setMaintenance: repair keeps the battery, back to service just restarts charging', async () => {
  await m.setMaintenance(5, true, 40);
  expect(sql()).toContain("status = 'maintenance'");
  expect(params()).toEqual([40, 5]);
  await m.setMaintenance(5, false);
  expect(sql()).toContain("status = 'available'");
  expect(sql()).not.toContain('battery_level');
  expect(params()).toEqual([5]);
});
