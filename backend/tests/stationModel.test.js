const { db, sql, params } = require('./modelHelpers');
const m = require('../src/models/stationModel');

beforeEach(() => jest.resetAllMocks());

test('listActive only returns active stations; listAll returns every station', async () => {
  db.query.mockResolvedValue([{ station_id: 1 }]);
  expect(await m.listActive()).toEqual([{ station_id: 1 }]);
  expect(sql()).toContain('WHERE is_active = 1');
  await m.listAll();
  expect(sql()).not.toContain('is_active = 1');
  expect(sql()).toContain('ORDER BY station_id');
});

test('findById: row or null', async () => {
  db.query.mockResolvedValue([{ station_id: 2 }]);
  expect(await m.findById(2)).toEqual({ station_id: 2 });
  expect(params()).toEqual([2]);
  db.query.mockResolvedValue([]);
  expect(await m.findById(2)).toBeNull();
});

test('nameTaken is case-insensitive and ignores the station being edited', async () => {
  db.query.mockResolvedValue([{ 1: 1 }]);
  expect(await m.nameTaken('Library', 4)).toBe(true);
  expect(sql()).toContain('LOWER(name) = LOWER(?) AND station_id <> ?');
  expect(params()).toEqual(['Library', 4]);
  db.query.mockResolvedValue([]);
  expect(await m.nameTaken('Library')).toBe(false);
  expect(params()).toEqual(['Library', 0]);
});

test('create: default icon is building, returns insertId', async () => {
  db.query.mockResolvedValue({ insertId: 7 });
  expect(await m.create({ name: 'Library', total_docks: 8 })).toBe(7);
  expect(params()).toEqual(['Library', 8, 'building']);
  await m.create({ name: 'Canteen', total_docks: 5, icon_key: 'canteen' });
  expect(params()).toEqual(['Canteen', 5, 'canteen']);
});

test('update stores is_active as 1 / 0', async () => {
  await m.update(3, { name: 'B3', total_docks: 10, is_active: true, icon_key: 'school' });
  expect(params()).toEqual(['B3', 10, 1, 'school', 3]);
  await m.update(3, { name: 'B3', total_docks: 10, is_active: false, icon_key: 'school' });
  expect(params()[2]).toBe(0);
});

test('setPhoto (also used with null to remove)', async () => {
  await m.setPhoto(3, '/uploads/s.png');
  expect(params()).toEqual(['/uploads/s.png', 3]);
  await m.setPhoto(3, null);
  expect(params()).toEqual([null, 3]);
});

test('countDocked counts every vehicle parked there; countOpenRidesFrom only open rides', async () => {
  db.query.mockResolvedValue([{ n: 4 }]);
  expect(await m.countDocked(1)).toBe(4);
  expect(sql()).toContain('current_station_id = ?');
  expect(await m.countOpenRidesFrom(1)).toBe(4);
  expect(sql()).toContain("status IN ('active','overdue')");
});
