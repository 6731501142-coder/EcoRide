jest.mock('../src/models/stationModel');
jest.mock('../src/models/vehicleModel');
jest.mock('../src/services/uploadService');
const stationModel = require('../src/models/stationModel');
const vehicleModel = require('../src/models/vehicleModel');
const uploads = require('../src/services/uploadService');
const c = require('../src/controllers/adminStationController');
const { run, fails, vehicleRow, station, admin } = require('./helpers');

const user = admin();
beforeEach(() => {
  jest.resetAllMocks();
  stationModel.findById.mockResolvedValue(station());
  stationModel.nameTaken.mockResolvedValue(false);
  stationModel.countDocked.mockResolvedValue(2);
  stationModel.countOpenRidesFrom.mockResolvedValue(0);
  stationModel.create.mockResolvedValue(4);
  vehicleModel.listAtStation.mockResolvedValue([vehicleRow()]);
});

describe('create', () => {
  test('ok -> 201 with availability, default icon', async () => {
    stationModel.findById.mockResolvedValue(station({ station_id: 4, name: 'Library', total_docks: 8 }));
    vehicleModel.listAtStation.mockResolvedValue([vehicleRow({ current_station_id: 4 })]);
    const { status, body } = await run(c.create, { user, body: { name: '  Library ', total_docks: '8' } });
    expect(status).toBe(201);
    expect(stationModel.create).toHaveBeenCalledWith({ name: 'Library', total_docks: 8, icon_key: 'building' });
    expect(body).toMatchObject({ station_id: 4, free_docks: 7 });
  });
  test('icon key is saved', async () => {
    await run(c.create, { user, body: { name: 'Library', total_docks: 8, icon_key: 'books' } });
    expect(stationModel.create.mock.calls[0][0].icon_key).toBe('books');
  });
  test('name required / too long / already used', async () => {
    expect(await fails(c.create, { user, body: { name: '  ', total_docks: 5 } })).toMatchObject({ status: 400, message: 'Station name is required' });
    expect((await fails(c.create, { user, body: { name: 'x'.repeat(51), total_docks: 5 } })).status).toBe(400);
    stationModel.nameTaken.mockResolvedValue(true);
    expect(await fails(c.create, { user, body: { name: 'Building 1', total_docks: 5 } })).toMatchObject({ status: 409, message: 'This name is already used' });
    expect(stationModel.nameTaken).toHaveBeenCalledWith('Building 1', 0);
  });
  test.each([[0], [-1], ['x'], [1.5], [null], [70000]])('docks %p is rejected', async (total_docks) => {
    expect((await fails(c.create, { user, body: { name: 'Library', total_docks } })).status).toBe(400);
  });
  test('unknown icon', async () => {
    expect(await fails(c.create, { user, body: { name: 'Library', total_docks: 5, icon_key: 'rocket' } })).toMatchObject({ status: 400, message: 'Unknown icon' });
  });
  test('all nine icons from the app are accepted', () => {
    expect(c.ICON_KEYS).toEqual(['building', 'school', 'books', 'flask', 'canteen', 'dorm', 'sport', 'park', 'parking']);
  });
});

describe('update', () => {
  const body = { name: 'Building 1', total_docks: 10, is_active: true };
  const req = (b = body) => ({ user, params: { id: '1' }, body: b });

  test('ok', async () => {
    await run(c.update, req({ name: ' Main Building ', total_docks: 12, is_active: true, icon_key: 'school' }));
    expect(stationModel.update).toHaveBeenCalledWith(1, { name: 'Main Building', total_docks: 12, is_active: true, icon_key: 'school' });
    expect(stationModel.nameTaken).toHaveBeenCalledWith('Main Building', 1); // its own name does not count
  });
  test('keeps the icon and active flag when they are not sent', async () => {
    await run(c.update, req({ name: 'B1', total_docks: 10 }));
    expect(stationModel.update).toHaveBeenCalledWith(1, { name: 'B1', total_docks: 10, is_active: true, icon_key: 'building' });
  });
  test('unknown station', async () => {
    stationModel.findById.mockResolvedValue(null);
    expect(await fails(c.update, req())).toMatchObject({ status: 404, message: 'Station not found' });
  });
  test('cannot close while riders must still return here', async () => {
    stationModel.countOpenRidesFrom.mockResolvedValue(1);
    expect(await fails(c.update, req({ ...body, is_active: false }))).toMatchObject({ status: 409, message: 'Riders still need to return vehicles here' });
    expect(stationModel.update).not.toHaveBeenCalled();
  });
  test('can close when nobody has to return', async () => {
    await run(c.update, req({ ...body, is_active: false }));
    expect(stationModel.update.mock.calls[0][1].is_active).toBe(false);
  });
  test('docks cannot be fewer than the vehicles parked', async () => {
    stationModel.countDocked.mockResolvedValue(4);
    expect(await fails(c.update, req({ ...body, total_docks: 3 }))).toMatchObject({ status: 409, message: '4 vehicles are parked here – need at least 4 docks' });
    expect((await run(c.update, req({ ...body, total_docks: 4 }))).status).toBe(200);
  });
  test('name / docks validation', async () => {
    expect((await fails(c.update, req({ ...body, name: '' }))).message).toBe('Station name is required');
    stationModel.nameTaken.mockResolvedValue(true);
    expect((await fails(c.update, req())).message).toBe('This name is already used');
    stationModel.nameTaken.mockResolvedValue(false);
    expect((await fails(c.update, req({ ...body, total_docks: 0 }))).message).toBe('Docks must be at least 1');
  });
});

describe('photo', () => {
  test('upload: saves the file, stores the url and deletes the old photo', async () => {
    stationModel.findById.mockResolvedValue(station({ photo_url: '/uploads/old.jpg' }));
    uploads.saveImage.mockReturnValue('/uploads/station-1-new.jpg');
    await run(c.uploadPhoto, { user, params: { id: '1' }, body: { image_base64: 'AAAA', mime: 'image/jpeg' } });
    expect(uploads.saveImage).toHaveBeenCalledWith({ imageBase64: 'AAAA', mime: 'image/jpeg', prefix: 'station-1' });
    expect(stationModel.setPhoto).toHaveBeenCalledWith(1, '/uploads/station-1-new.jpg');
    expect(uploads.removeImage).toHaveBeenCalledWith('/uploads/old.jpg');
  });
  test('remove', async () => {
    stationModel.findById.mockResolvedValue(station({ photo_url: '/uploads/old.jpg' }));
    await run(c.removePhoto, { user, params: { id: '1' } });
    expect(stationModel.setPhoto).toHaveBeenCalledWith(1, null);
    expect(uploads.removeImage).toHaveBeenCalledWith('/uploads/old.jpg');
  });
  test('unknown station', async () => {
    stationModel.findById.mockResolvedValue(null);
    expect((await fails(c.uploadPhoto, { user, params: { id: '9' }, body: {} })).status).toBe(404);
    expect((await fails(c.removePhoto, { user, params: { id: '9' } })).status).toBe(404);
  });
});

test('list shows closed stations too', async () => {
  stationModel.listAll.mockResolvedValue([station(), station({ station_id: 2, is_active: 0 })]);
  vehicleModel.listDocked.mockResolvedValue([]);
  const { body } = await run(c.list, { user });
  expect(body.map((s) => s.is_active)).toEqual([true, false]);
});
