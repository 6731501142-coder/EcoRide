jest.mock('../src/models/vehicleModel');
jest.mock('../src/models/stationModel');
jest.mock('../src/models/catalogModel');
const vehicleModel = require('../src/models/vehicleModel');
const stationModel = require('../src/models/stationModel');
const catalogModel = require('../src/models/catalogModel');
const c = require('../src/controllers/adminVehicleController');
const { run, fails, vehicleRow, station, admin } = require('./helpers');

const user = admin();
const bike = { type_id: 1, code_prefix: 'EB', name: 'Electric bicycle' };

beforeEach(() => {
  jest.resetAllMocks();
  catalogModel.findType.mockResolvedValue(bike);
  vehicleModel.codeExists.mockResolvedValue(false);
  stationModel.findById.mockResolvedValue(station());
  stationModel.countDocked.mockResolvedValue(3);
  vehicleModel.create.mockResolvedValue(11);
  vehicleModel.findById.mockResolvedValue(vehicleRow({ vehicle_id: 11, vehicle_code: 'EB-007', battery_level: 100 }));
});

describe('add', () => {
  const body = { type_id: 1, number: 7, station_id: 1 };
  test('code = prefix + number padded to 3 digits, battery starts full, 201', async () => {
    const { status, body: out } = await run(c.add, { user, body });
    expect(status).toBe(201);
    expect(vehicleModel.codeExists).toHaveBeenCalledWith('EB-007');
    expect(vehicleModel.create).toHaveBeenCalledWith({ vehicle_code: 'EB-007', type_id: 1, station_id: 1 });
    expect(out).toMatchObject({ vehicle_code: 'EB-007', live_battery: 100 });
  });
  test('scooter prefix, 3-digit number', async () => {
    catalogModel.findType.mockResolvedValue({ type_id: 2, code_prefix: 'ES', name: 'Electric scooter' });
    await run(c.add, { user, body: { ...body, type_id: 2, number: '123' } });
    expect(vehicleModel.create.mock.calls[0][0].vehicle_code).toBe('ES-123');
  });
  test.each([[0], [-4], [1000], ['abc'], [3.5], [null]])('number %p -> Enter a number 1–999', async (number) => {
    expect(await fails(c.add, { user, body: { ...body, number } })).toMatchObject({ status: 400, message: 'Enter a number 1–999' });
  });
  test('999 and 1 are fine', async () => {
    await run(c.add, { user, body: { ...body, number: 999 } });
    await run(c.add, { user, body: { ...body, number: 1 } });
    expect(vehicleModel.create.mock.calls.map((x) => x[0].vehicle_code)).toEqual(['EB-999', 'EB-001']);
  });
  test('code already exists', async () => {
    vehicleModel.codeExists.mockResolvedValue(true);
    expect(await fails(c.add, { user, body })).toMatchObject({ status: 409, message: 'EB-007 already exists' });
  });
  test('station full', async () => {
    stationModel.countDocked.mockResolvedValue(10);
    expect(await fails(c.add, { user, body })).toMatchObject({ status: 409, message: 'Building 1 is full' });
    expect(vehicleModel.create).not.toHaveBeenCalled();
  });
  test('unknown type / station', async () => {
    catalogModel.findType.mockResolvedValue(null);
    expect(await fails(c.add, { user, body })).toMatchObject({ status: 404, message: 'Vehicle type not found' });
    expect((await fails(c.add, { user, body: { ...body, type_id: 'x' } })).status).toBe(404);
    catalogModel.findType.mockResolvedValue(bike);
    stationModel.findById.mockResolvedValue(null);
    expect(await fails(c.add, { user, body })).toMatchObject({ status: 404, message: 'Station not found' });
  });
  test('unique-key race is a friendly 409', async () => {
    vehicleModel.create.mockRejectedValue({ code: 'ER_DUP_ENTRY', sqlMessage: "for key 'uq_vehicles_code'" });
    expect((await fails(c.add, { user, body })).status).toBe(409);
  });
});

describe('setMaintenance', () => {
  const req = (repair) => ({ user, params: { id: '1' }, body: { repair } });
  beforeEach(() => vehicleModel.findById.mockResolvedValue(vehicleRow({ battery_level: 30, seconds_since_battery_update: 3600 })));

  test('send to repair: remembers the live battery (30% + 1 h of charging)', async () => {
    await run(c.setMaintenance, req(true));
    expect(vehicleModel.setMaintenance).toHaveBeenCalledWith(1, true, 52); // 30 + 22.86 -> 52
  });
  test('back to service', async () => {
    await run(c.setMaintenance, req(false));
    expect(vehicleModel.setMaintenance).toHaveBeenCalledWith(1, false, 52);
  });
  test('"repair": "true" (text) also works', async () => {
    await run(c.setMaintenance, req('true'));
    expect(vehicleModel.setMaintenance.mock.calls[0][1]).toBe(true);
  });
  test('cannot touch a vehicle somebody is riding', async () => {
    vehicleModel.findById.mockResolvedValue(vehicleRow({ status: 'in_use' }));
    expect(await fails(c.setMaintenance, req(true))).toMatchObject({ status: 409, message: 'Someone is riding this vehicle' });
    expect(vehicleModel.setMaintenance).not.toHaveBeenCalled();
  });
  test('unknown vehicle', async () => {
    vehicleModel.findById.mockResolvedValue(null);
    expect(await fails(c.setMaintenance, req(true))).toMatchObject({ status: 404, message: 'Vehicle not found' });
  });
});

test('list returns every vehicle with live fields', async () => {
  vehicleModel.listAll.mockResolvedValue([vehicleRow(), vehicleRow({ vehicle_id: 2, status: 'maintenance' })]);
  const { body } = await run(c.list, { user });
  expect(body).toHaveLength(2);
  expect(body[1]).toMatchObject({ status: 'maintenance', can_borrow: false });
});
