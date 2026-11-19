const { db, sql, params, fakeConnection } = require('./modelHelpers');
const m = require('../src/models/rideModel');

beforeEach(() => jest.resetAllMocks());

test('the shared SELECT carries names, duration and is_overdue', async () => {
  db.query.mockResolvedValue([]);
  await m.listAll();
  expect(sql()).toContain('vehicle_code');
  expect(sql()).toContain('AS from_station');
  expect(sql()).toContain('AS duration_min');
  expect(sql()).toContain("r.status = 'overdue' OR (r.status = 'active' AND r.due_time < NOW())");
  expect(sql()).toContain('ORDER BY r.start_time DESC');
});

test('findById: row or null', async () => {
  db.query.mockResolvedValue([{ ride_id: 7 }]);
  expect(await m.findById(7)).toEqual({ ride_id: 7 });
  db.query.mockResolvedValue([]);
  expect(await m.findById(7)).toBeNull();
});

test('findOpenByUser looks only at active / overdue rides, newest first', async () => {
  db.query.mockResolvedValue([{ ride_id: 7 }]);
  expect(await m.findOpenByUser(1)).toEqual({ ride_id: 7 });
  expect(sql()).toContain("r.status IN ('active','overdue')");
  expect(sql()).toContain('LIMIT 1');
  expect(params()).toEqual([1]);
  db.query.mockResolvedValue([]);
  expect(await m.findOpenByUser(1)).toBeNull();
});

test('listByUser / listOpen', async () => {
  db.query.mockResolvedValue([]);
  await m.listByUser(4);
  expect(sql()).toContain('WHERE r.user_id = ?');
  expect(params()).toEqual([4]);
  await m.listOpen();
  expect(sql()).toContain('ORDER BY is_overdue DESC, r.due_time ASC');
});

describe('monthlyStats', () => {
  test('reads the view', async () => {
    db.query.mockResolvedValue([{ user_id: 1, rides_this_month: 3, hours_total: 4.5, spent_this_month: 300 }]);
    expect((await m.monthlyStats(1)).rides_this_month).toBe(3);
    expect(sql()).toContain('FROM v_user_monthly_stats');
  });
  test('a student with no rides gets zeros, not null', async () => {
    db.query.mockResolvedValue([]);
    expect(await m.monthlyStats(9)).toEqual({ user_id: 9, rides_this_month: 0, hours_total: 0, spent_this_month: 0 });
  });
});

describe('stored procedures', () => {
  test('callBorrow: CALL sp_borrow_vehicle with an OUT parameter, returns the ride id', async () => {
    const conn = fakeConnection([[{}], [[{ ride_id: 21 }]]]);
    expect(await m.callBorrow(1, 2, 3)).toBe(21);
    expect(conn.query).toHaveBeenNthCalledWith(1, 'CALL sp_borrow_vehicle(?, ?, ?, @ride_id)', [1, 2, 3]);
    expect(conn.query.mock.calls[1][0]).toContain('@ride_id');
  });
  test('callBorrow passes the procedure error up (and still releases the connection)', async () => {
    const conn = { query: jest.fn().mockRejectedValue({ sqlState: '45000', sqlMessage: 'Vehicle is not available' }) };
    db.withConnection.mockImplementation(async (fn) => fn(conn));
    await expect(m.callBorrow(1, 2, 3)).rejects.toMatchObject({ sqlMessage: 'Vehicle is not available' });
  });
  test('callReturn: CALL sp_return_vehicle(ride, station, battery_end)', async () => {
    const conn = fakeConnection([[{}]]);
    await m.callReturn(7, 1, 68);
    expect(conn.query).toHaveBeenCalledWith('CALL sp_return_vehicle(?, ?, ?)', [7, 1, 68]);
  });
});
