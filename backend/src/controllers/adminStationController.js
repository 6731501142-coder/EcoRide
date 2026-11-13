// Admin > Stations  (= saveStation / setStationLook in AppStore)
const stationModel = require('../models/stationModel');
const vehicleModel = require('../models/vehicleModel');
const vs = require('../services/vehicleService');
const uploads = require('../services/uploadService');
const { badRequest, notFound, conflict, mapDbError } = require('../utils/errors');
const { str, toInt, bool } = require('../utils/helpers');

// same keys as stationIcons in station_pic.dart
const ICON_KEYS = ['building', 'school', 'books', 'flask', 'canteen', 'dorm', 'sport', 'park', 'parking'];

const view = async (id) => {
  const [s, docked] = await Promise.all([stationModel.findById(id), vehicleModel.listAtStation(id)]);
  return vs.withAvailability(s, docked.map((v) => vs.decorate(v)));
};

async function getStation(req) {
  const id = toInt(req.params.id);
  const s = id === null ? null : await stationModel.findById(id);
  if (!s) throw notFound('Station not found');
  return s;
}

/** the checks shared by create and update (messages from AppStore.saveStation) */
async function checkFields(body, exceptId) {
  const name = str(body?.name);
  if (!name) throw badRequest('Station name is required');
  if (name.length > 50) throw badRequest('Station name is too long (max 50 characters)');
  if (await stationModel.nameTaken(name, exceptId)) throw conflict('This name is already used');
  const docks = toInt(body?.total_docks);
  if (docks === null || docks < 1) throw badRequest('Docks must be at least 1');
  if (docks > 65535) throw badRequest('Too many docks');
  const iconKey = body?.icon_key === undefined ? undefined : String(body.icon_key);
  if (iconKey !== undefined && !ICON_KEYS.includes(iconKey)) throw badRequest('Unknown icon');
  return { name, docks, iconKey };
}

/** GET /admin/stations  (includes closed stations) */
async function list(req, res) {
  const [stations, docked] = await Promise.all([stationModel.listAll(), vehicleModel.listDocked()]);
  const d = docked.map((v) => vs.decorate(v));
  res.json(stations.map((s) => vs.withAvailability(s, d)));
}

/** POST /admin/stations  { name, total_docks, icon_key? } -> 201 */
async function create(req, res) {
  const { name, docks, iconKey } = await checkFields(req.body, 0);
  try {
    const id = await stationModel.create({ name, total_docks: docks, icon_key: iconKey || 'building' });
    res.status(201).json(await view(id));
  } catch (e) {
    throw mapDbError(e);
  }
}

/** PUT /admin/stations/:id  { name, total_docks, is_active, icon_key? } */
async function update(req, res) {
  const st = await getStation(req);
  const { name, docks, iconKey } = await checkFields(req.body, st.station_id);
  const active = req.body?.is_active === undefined ? !!st.is_active : bool(req.body.is_active);

  // can't close a station while riders still have to return vehicles here
  if (!active && (await stationModel.countOpenRidesFrom(st.station_id)) > 0) {
    throw conflict('Riders still need to return vehicles here');
  }
  const parked = await stationModel.countDocked(st.station_id);
  if (docks < parked) throw conflict(`${parked} vehicles are parked here – need at least ${parked} docks`);

  try {
    await stationModel.update(st.station_id, { name, total_docks: docks, is_active: active, icon_key: iconKey || st.icon_key });
    res.json(await view(st.station_id));
  } catch (e) {
    throw mapDbError(e);
  }
}

/** POST /admin/stations/:id/photo  { image_base64, mime } */
async function uploadPhoto(req, res) {
  const st = await getStation(req);
  const url = uploads.saveImage({ imageBase64: req.body?.image_base64, mime: req.body?.mime, prefix: `station-${st.station_id}` });
  uploads.removeImage(st.photo_url);
  await stationModel.setPhoto(st.station_id, url);
  res.json(await view(st.station_id));
}

/** DELETE /admin/stations/:id/photo  (setStationLook(removePhoto: true)) */
async function removePhoto(req, res) {
  const st = await getStation(req);
  uploads.removeImage(st.photo_url);
  await stationModel.setPhoto(st.station_id, null);
  res.json(await view(st.station_id));
}

module.exports = { list, create, update, uploadPhoto, removePhoto, ICON_KEYS };
