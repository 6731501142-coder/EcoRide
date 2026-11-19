jest.mock('../src/models/stationModel');
jest.mock('../src/models/vehicleModel');
jest.mock('../src/models/catalogModel');
const stationModel = require('../src/models/stationModel');
const vehicleModel = require('../src/models/vehicleModel');
const catalogModel = require('../src/models/catalogModel');
const c = require('../src/controllers/catalogController');
const { run, fails, vehicleRow, scooterRow, station } = require('./helpers');

beforeEach(() => jest.resetAllMocks());

test('listStations: active stations with availability from docked vehicles', async () => {
  stationModel.listActive.mockResolvedValue([station({ station_id: 1, total_docks: 10 }), station({ station_id: 2, name: 'Library', total_docks: 4 })]);
  vehicleModel.listDocked.mockResolvedValue([vehicleRow(), scooterRow({ battery_level: 12 })]);
  const { body } = await run(c.listStations);
  expect(body).toHaveLength(2);
  expect(body[0]).toMatchObject({ station_id: 1, vehicles_docked: 2, free_docks: 8, ready_to_ride: 1, bikes: 1, scooters: 1, is_active: true });
  expect(body[1]).toMatchObject({ station_id: 2, vehicles_docked: 0, free_docks: 4, is_full: false });
});

describe('vehiclesAtStation', () => {
  test('borrowable and fullest first', async () => {
    stationModel.findById.mockResolvedValue(station());
    vehicleModel.listAtStation.mockResolvedValue([
      scooterRow({ battery_level: 12 }),
      vehicleRow({ vehicle_id: 1, battery_level: 50 }),
      vehicleRow({ vehicle_id: 2, vehicle_code: 'EB-015', battery_level: 90 }),
    ]);
    const { body } = await run(c.vehiclesAtStation, { params: { id: '1' } });
    expect(body.map((v) => v.vehicle_id)).toEqual([2, 1, 3]);
    expect(body[2]).toMatchObject({ can_borrow: false, is_charging: true });
  });
  test('unknown or non numeric station -> 404', async () => {
    stationModel.findById.mockResolvedValue(null);
    expect(await fails(c.vehiclesAtStation, { params: { id: '99' } })).toMatchObject({ status: 404, message: 'Station not found' });
    expect(await fails(c.vehiclesAtStation, { params: { id: 'abc' } })).toMatchObject({ status: 404 });
  });
});

test('listVehicles: all vehicles, each with live fields', async () => {
  vehicleModel.listAll.mockResolvedValue([vehicleRow(), scooterRow({ status: 'in_use', current_station_id: null })]);
  const { body } = await run(c.listVehicles);
  expect(body).toHaveLength(2);
  expect(body[0]).toMatchObject({ vehicle_id: 1, live_battery: 79, can_borrow: true });
  expect(body[1]).toMatchObject({ vehicle_id: 3, can_borrow: false });
});

describe('vehicleByCode', () => {
  test('ok', async () => {
    vehicleModel.findByCode.mockResolvedValue(vehicleRow());
    const { body } = await run(c.vehicleByCode, { params: { code: ' EB-012 ' } });
    expect(vehicleModel.findByCode).toHaveBeenCalledWith('EB-012');
    expect(body).toMatchObject({ vehicle_code: 'EB-012', live_battery: 79, can_borrow: true });
  });
  test('missing -> 404, empty -> 400', async () => {
    vehicleModel.findByCode.mockResolvedValue(null);
    expect(await fails(c.vehicleByCode, { params: { code: 'XX-1' } })).toMatchObject({ status: 404, message: 'Vehicle not found' });
    expect(await fails(c.vehicleByCode, { params: { code: '  ' } })).toMatchObject({ status: 400 });
  });
});

test('types and plans are passed through', async () => {
  catalogModel.listTypes.mockResolvedValue([{ type_id: 1 }]);
  catalogModel.listPlans.mockResolvedValue([{ plan_id: 1 }]);
  expect((await run(c.listTypes)).body).toEqual([{ type_id: 1 }]);
  expect((await run(c.listPlans)).body).toEqual([{ plan_id: 1 }]);
});
