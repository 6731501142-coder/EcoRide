// Admin > Vehicles  (= addVehicle / setMaintenance in AppStore)
const vehicleModel = require('../models/vehicleModel');
const stationModel = require('../models/stationModel');
const catalogModel = require('../models/catalogModel');
const vs = require('../services/vehicleService');
const battery = require('../services/batteryService');
const { badRequest, notFound, conflict, mapDbError } = require('../utils/errors');
const { toInt, bool } = require('../utils/helpers');

/** GET /admin/vehicles */
async function list(req, res) {
  res.json((await vehicleModel.listAll()).map((v) => vs.decorate(v)));
}

/** POST /admin/vehicles  { type_id, number, station_id } -> 201.  code = EB-012 / ES-007 */
async function add(req, res) {
  const type = toInt(req.body?.type_id) === null ? null : await catalogModel.findType(toInt(req.body.type_id));
  if (!type) throw notFound('Vehicle type not found');

  const n = toInt(req.body?.number);
  if (n === null || n <= 0 || n > 999) throw badRequest('Enter a number 1–999');
  const code = `${type.code_prefix}-${String(n).padStart(3, '0')}`;
  if (await vehicleModel.codeExists(code)) throw conflict(`${code} already exists`);

  const stationId = toInt(req.body?.station_id);
  const station = stationId === null ? null : await stationModel.findById(stationId);
  if (!station) throw notFound('Station not found');
  if ((await stationModel.countDocked(station.station_id)) >= station.total_docks) throw conflict(`${station.name} is full`);

  try {
    const id = await vehicleModel.create({ vehicle_code: code, type_id: type.type_id, station_id: station.station_id });
    res.status(201).json(vs.decorate(await vehicleModel.findById(id)));
  } catch (e) {
    throw mapDbError(e);
  }
}

/** PUT /admin/vehicles/:id/maintenance  { repair: true | false } */
async function setMaintenance(req, res) {
  const id = toInt(req.params.id);
  const v = id === null ? null : await vehicleModel.findById(id);
  if (!v) throw notFound('Vehicle not found');
  if (v.status === 'in_use') throw conflict('Someone is riding this vehicle');

  const repair = bool(req.body?.repair);
  await vehicleModel.setMaintenance(v.vehicle_id, repair, battery.liveBattery(v));
  res.json(vs.decorate(await vehicleModel.findById(v.vehicle_id)));
}

module.exports = { list, add, setMaintenance };
