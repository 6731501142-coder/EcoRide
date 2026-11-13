jest.mock('../src/models/rideModel');
jest.mock('../src/models/vehicleModel');
jest.mock('../src/models/stationModel');
jest.mock('../src/models/catalogModel');
jest.mock('../src/models/reportModel');
jest.mock('../src/models/userModel');
const rideModel = require('../src/models/rideModel');
const vehicleModel = require('../src/models/vehicleModel');
const stationModel = require('../src/models/stationModel');
const catalogModel = require('../src/models/catalogModel');
const reportModel = require('../src/models/reportModel');
const userModel = require('../src/models/userModel');
const c = require('../src/controllers/rideController');
const { run, fails, vehicleRow, rideRow, station, student } = require('./helpers');

const user = student({ credit_balance: 150 });
const plan = { plan_id: 1, name: '1 day', price: 100 };

beforeEach(() => {
  jest.resetAllMocks();
  rideModel.findOpenByUser.mockResolvedValue(null);
  rideModel.findById.mockResolvedValue(rideRow());
  rideModel.callBorrow.mockResolvedValue(7);
  vehicleModel.findById.mockResolvedValue(vehicleRow());
  stationModel.findById.mockResolvedValue(station());
  stationModel.countDocked.mockResolvedValue(3);
  catalogModel.listPlans.mockResolvedValue([plan]);
  catalogModel.findPlan.mockResolvedValue(plan);
  userModel.findById.mockResolvedValue(student({ credit_balance: 50 }));
  reportModel.create.mockResolvedValue(11);
  reportModel.findById.mockResolvedValue({ report_id: 11 });
});

describe('activeRide / myRides / myStats', () => {
  test('no open ride -> null', async () => {
    expect((await run(c.activeRide, { user })).body).toBeNull();
  });
  test('open ride includes live battery and boolean is_overdue', async () => {
    rideModel.findOpenByUser.mockResolvedValue(rideRow({ is_overdue: 1 }));
    vehicleModel.findById.mockResolvedValue(vehicleRow({ status: 'in_use', current_station_id: null, ride_battery_start: 90, ride_used_seconds: 3600 }));
    const { body } = await run(c.activeRide, { user });
    expect(body).toMatchObject({ ride_id: 7, is_overdue: true, battery_now: 79 });
  });
  test('history rows get boolean is_overdue', async () => {
    rideModel.listByUser.mockResolvedValue([rideRow({ is_overdue: 0 }), rideRow({ ride_id: 8, is_overdue: 1 })]);
    const { body } = await run(c.myRides, { user });
    expect(rideModel.listByUser).toHaveBeenCalledWith(1);
    expect(body.map((r) => r.is_overdue)).toEqual([false, true]);
  });
  test('stats come straight from the view', async () => {
    rideModel.monthlyStats.mockResolvedValue({ user_id: 1, rides_this_month: 2, hours_total: 3.5, spent_this_month: 200 });
    expect((await run(c.myStats, { user })).body).toMatchObject({ rides_this_month: 2, spent_this_month: 200 });
  });
});

describe('borrow', () => {
  test('ok -> 201 { ride, user } using the default (first) plan', async () => {
    const { status, body } = await run(c.borrow, { user, body: { vehicle_id: 1 } });
    expect(status).toBe(201);
    expect(rideModel.callBorrow).toHaveBeenCalledWith(1, 1, 1);
    expect(body.ride.ride_id).toBe(7);
    expect(body.user.credit_balance).toBe(50);
  });
  test('explicit plan is used', async () => {
    catalogModel.findPlan.mockResolvedValue({ plan_id: 2, price: 30 });
    await run(c.borrow, { user, body: { vehicle_id: '1', plan_id: 2 } });
    expect(rideModel.callBorrow).toHaveBeenCalledWith(1, 1, 2);
  });
  test('saves the live battery before calling the procedure when it changed', async () => {
    vehicleModel.findById.mockResolvedValue(vehicleRow({ battery_level: 60, seconds_since_battery_update: 3600 }));
    await run(c.borrow, { user, body: { vehicle_id: 1 } });
    expect(vehicleModel.saveBattery).toHaveBeenCalledWith(1, expect.any(Number));
    expect(vehicleModel.saveBattery.mock.calls[0][1]).toBeGreaterThan(60);
  });
  test('does not rewrite the battery when unchanged', async () => {
    await run(c.borrow, { user, body: { vehicle_id: 1 } });
    expect(vehicleModel.saveBattery).not.toHaveBeenCalled();
  });
  test('vehicle_id missing -> 400', async () => {
    expect(await fails(c.borrow, { user, body: {} })).toMatchObject({ status: 400 });
  });
  test('already has a vehicle out -> 409', async () => {
    rideModel.findOpenByUser.mockResolvedValue(rideRow());
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 409, message: 'You already have a vehicle out. Return it first.' });
  });
  test('vehicle not found -> 404', async () => {
    vehicleModel.findById.mockResolvedValue(null);
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 404 });
  });
  test('in use / maintenance / not docked -> 409 "<code> is not available"', async () => {
    for (const patch of [{ status: 'in_use' }, { status: 'maintenance' }, { current_station_id: null }]) {
      vehicleModel.findById.mockResolvedValue(vehicleRow(patch));
      expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 409, message: 'EB-012 is not available' });
    }
  });
  test('battery below 20% -> 409', async () => {
    vehicleModel.findById.mockResolvedValue(vehicleRow({ battery_level: 10 }));
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 409, message: 'Battery is below 20%. Please choose another vehicle.' });
  });
  test('not enough credit -> 409, exactly enough is fine', async () => {
    expect(await fails(c.borrow, { user: student({ credit_balance: 99 }), body: { vehicle_id: 1 } })).toMatchObject({ status: 409, message: 'Not enough credit. Please top up first.' });
    await run(c.borrow, { user: student({ credit_balance: 100 }), body: { vehicle_id: 1 } });
    expect(rideModel.callBorrow).toHaveBeenCalledTimes(1);
  });
  test('plan not found -> 404', async () => {
    catalogModel.findPlan.mockResolvedValue(null);
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1, plan_id: 99 } })).toMatchObject({ status: 404 });
    catalogModel.listPlans.mockResolvedValue([]);
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 404 });
  });
  test('procedure SIGNAL becomes 409 with its message', async () => {
    rideModel.callBorrow.mockRejectedValue({ sqlState: '45000', sqlMessage: 'Vehicle is not available' });
    expect(await fails(c.borrow, { user, body: { vehicle_id: 1 } })).toMatchObject({ status: 409, message: 'Vehicle is not available' });
  });
});

describe('returnVehicle', () => {
  const inUse = () => vehicleRow({ status: 'in_use', current_station_id: null, ride_battery_start: 79, ride_used_seconds: 3600 });
  beforeEach(() => {
    vehicleModel.findById.mockResolvedValue(inUse());
    rideModel.findById.mockResolvedValue(rideRow({ status: 'active' }));
  });
  test('ok: battery_end is computed on the server', async () => {
    rideModel.findById.mockResolvedValueOnce(rideRow()).mockResolvedValue(rideRow({ status: 'returned', battery_end: 68 }));
    const { body } = await run(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } });
    expect(rideModel.callReturn).toHaveBeenCalledWith(7, 1, 68);
    expect(body.status).toBe('returned');
  });
  test('ride not found -> 404; not mine -> 403; already returned -> 409', async () => {
    rideModel.findById.mockResolvedValue(null);
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } })).toMatchObject({ status: 404, message: 'Ride not found' });
    expect(await fails(c.returnVehicle, { user, params: { id: 'x' }, body: { station_id: 1 } })).toMatchObject({ status: 404 });
    rideModel.findById.mockResolvedValue(rideRow({ user_id: 99 }));
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } })).toMatchObject({ status: 403 });
    rideModel.findById.mockResolvedValue(rideRow({ status: 'returned' }));
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } })).toMatchObject({ status: 409, message: 'This ride is already finished' });
  });
  test('station does not exist -> 404', async () => {
    stationModel.findById.mockResolvedValue(null);
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 99 } })).toMatchObject({ status: 404, message: 'Station not found' });
    rideModel.findById.mockReset();
    rideModel.findById.mockResolvedValue(rideRow());
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: {} })).toMatchObject({ status: 404 });
  });
  test('must return to the station it was borrowed from', async () => {
    stationModel.findById.mockResolvedValue(station({ station_id: 2, name: 'Library' }));
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 2 } })).toMatchObject({ status: 409, message: 'You can only return to Building 1' });
  });
  test('full station -> 409', async () => {
    stationModel.countDocked.mockResolvedValue(10);
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } })).toMatchObject({ status: 409, message: 'Building 1 is full' });
    expect(rideModel.callReturn).not.toHaveBeenCalled();
  });
  test('procedure error is mapped', async () => {
    rideModel.callReturn.mockRejectedValue({ sqlState: '45000', sqlMessage: 'Station is full' });
    expect(await fails(c.returnVehicle, { user, params: { id: '7' }, body: { station_id: 1 } })).toMatchObject({ status: 409, message: 'Station is full' });
  });
});

describe('requestHelp', () => {
  const body = { type: 'flatTyre', location: ' Near the library ', details: ' rear wheel ' };
  test('creates an urgent report with the [URGENT] prefix the app looks for', async () => {
    const { status } = await run(c.requestHelp, { user, params: { id: '7' }, body });
    expect(status).toBe(201);
    expect(reportModel.create).toHaveBeenCalledWith({
      user_id: 1, vehicle_id: 1, ride_id: 7, category: 'brakes_wheels', is_urgent: true,
      location: 'Near the library', details: '[URGENT] Flat tyre · at: Near the library · rear wheel',
    });
  });
  test('no details -> no trailing separator', async () => {
    await run(c.requestHelp, { user, params: { id: '7' }, body: { type: 'other', location: 'here' } });
    expect(reportModel.create.mock.calls[0][0].details).toBe('[URGENT] Something else · at: here');
  });
  test.each([
    ['accident', 'accident'], ['flatTyre', 'brakes_wheels'], ['flat_tyre', 'brakes_wheels'], ['brakes', 'brakes_wheels'],
    ['damaged', 'damaged_part'], ['battery', 'low_battery'], ['other', 'other'],
  ])('help type %s -> category %s', async (type, category) => {
    await run(c.requestHelp, { user, params: { id: '7' }, body: { type, location: 'x' } });
    expect(reportModel.create.mock.calls[0][0].category).toBe(category);
  });
  test('bad type / no location -> 400', async () => {
    expect(await fails(c.requestHelp, { user, params: { id: '7' }, body: { type: 'zzz', location: 'x' } })).toMatchObject({ status: 400, message: 'Unknown help type' });
    expect(await fails(c.requestHelp, { user, params: { id: '7' }, body: { type: 'other', location: '  ' } })).toMatchObject({ status: 400, message: 'Please tell staff where you are' });
  });
  test("others' or finished rides are refused", async () => {
    rideModel.findById.mockResolvedValue(rideRow({ user_id: 5 }));
    expect(await fails(c.requestHelp, { user, params: { id: '7' }, body })).toMatchObject({ status: 403 });
    rideModel.findById.mockResolvedValue(rideRow({ status: 'returned' }));
    expect(await fails(c.requestHelp, { user, params: { id: '7' }, body })).toMatchObject({ status: 409 });
  });
});
