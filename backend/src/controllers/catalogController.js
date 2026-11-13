// stations, vehicles, plans – what the student sees on Home / pick a vehicle
const stationModel = require('../models/stationModel');
const vehicleModel = require('../models/vehicleModel');
const catalogModel = require('../models/catalogModel');
const vs = require('../services/vehicleService');
const { notFound, badRequest } = require('../utils/errors');
const { toInt } = require('../utils/helpers');

/** GET /stations  active stations + availability (= v_station_availability with live battery) */
async function listStations(req, res) {
  const [stations, docked] = await Promise.all([stationModel.listActive(), vehicleModel.listDocked()]);
  const decorated = docked.map((v) => vs.decorate(v));
  res.json(stations.map((s) => vs.withAvailability(s, decorated)));
}

/** GET /stations/:id/vehicles  vehicles parked here, borrowable first */
async function vehiclesAtStation(req, res) {
  const id = toInt(req.params.id);
  const station = id === null ? null : await stationModel.findById(id);
  if (!station) throw notFound('Station not found');
  const list = (await vehicleModel.listAtStation(id)).map((v) => vs.decorate(v));
  res.json(vs.sortForStation(list));
}

/** GET /vehicles  every vehicle (docked or out) with live battery – the app keeps this list like its old in-memory list */
async function listVehicles(req, res) {
  res.json((await vehicleModel.listAll()).map((v) => vs.decorate(v)));
}

/** GET /vehicles/by-code/:code  (scan QR / type the code) */
async function vehicleByCode(req, res) {
  const code = String(req.params.code || '').trim();
  if (!code) throw badRequest('Vehicle code is required');
  const v = await vehicleModel.findByCode(code);
  if (!v) throw notFound('Vehicle not found');
  res.json(vs.decorate(v));
}

/** GET /vehicle-types */
const listTypes = async (req, res) => res.json(await catalogModel.listTypes());

/** GET /rental-plans  (active only; the app uses the first one as the default plan) */
const listPlans = async (req, res) => res.json(await catalogModel.listPlans());

module.exports = { listStations, vehiclesAtStation, listVehicles, vehicleByCode, listTypes, listPlans };
