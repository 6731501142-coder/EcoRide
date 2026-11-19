// Borrow, return, history, "Need help?"  (= borrow() / returnVehicle() / requestHelp() in AppStore)
// The rules are checked here first (so the messages are exactly the ones the app shows),
// then the stored procedure does the real work inside a transaction.
const rideModel = require('../models/rideModel');
const vehicleModel = require('../models/vehicleModel');
const stationModel = require('../models/stationModel');
const catalogModel = require('../models/catalogModel');
const reportModel = require('../models/reportModel');
const userModel = require('../models/userModel');
const battery = require('../services/batteryService');
const config = require('../config');
const { badRequest, notFound, forbidden, conflict, mapDbError } = require('../utils/errors');
const { str, toInt } = require('../utils/helpers');
const { publicUser } = require('./authController');

const ride = (r) => (r ? { ...r, is_overdue: !!r.is_overdue } : r);

/** the ride must exist and belong to the person asking */
async function ownRide(req) {
  const id = toInt(req.params.id);
  const r = id === null ? null : await rideModel.findById(id);
  if (!r) throw notFound('Ride not found');
  if (r.user_id !== req.user.user_id) throw forbidden('This is not your ride');
  return r;
}

/** GET /rides/active -> the ride I have not returned yet (+ battery now), or null */
async function activeRide(req, res) {
  const r = await rideModel.findOpenByUser(req.user.user_id);
  if (!r) return res.json(null);
  const v = await vehicleModel.findById(r.vehicle_id);
  res.json({ ...ride(r), battery_now: v ? battery.liveBattery(v) : null });
}

/** GET /rides -> my history, newest first (= v_ride_history) */
async function myRides(req, res) {
  res.json((await rideModel.listByUser(req.user.user_id)).map(ride));
}

/** GET /rides/stats -> this month (= v_user_monthly_stats) */
async function myStats(req, res) {
  res.json(await rideModel.monthlyStats(req.user.user_id));
}

/** POST /rides  { vehicle_id, plan_id? } -> 201 { ride, user } */
async function borrow(req, res) {
  const me = req.user;
  const vehicleId = toInt(req.body?.vehicle_id);
  if (vehicleId === null) throw badRequest('vehicle_id is required');

  if (await rideModel.findOpenByUser(me.user_id)) throw conflict('You already have a vehicle out. Return it first.');

  const v = await vehicleModel.findById(vehicleId);
  if (!v) throw notFound('Vehicle not found');
  if (v.status !== 'available' || v.current_station_id == null) throw conflict(`${v.vehicle_code} is not available`);

  const live = battery.liveBattery(v);
  if (live < config.minBattery) throw conflict(`Battery is below ${config.minBattery}%. Please choose another vehicle.`);

  let planId = toInt(req.body?.plan_id);
  if (planId === null) planId = (await catalogModel.listPlans())[0]?.plan_id ?? null; // default plan
  const plan = planId === null ? null : await catalogModel.findPlan(planId);
  if (!plan) throw notFound('Rental plan not found');
  if (me.credit_balance < plan.price) throw conflict('Not enough credit. Please top up first.');

  try {
    // the procedure reads vehicles.battery_level, so save the live value first
    if (live !== v.battery_level) await vehicleModel.saveBattery(v.vehicle_id, live);
    const rideId = await rideModel.callBorrow(me.user_id, v.vehicle_id, plan.plan_id);
    res.status(201).json({
      ride: ride(await rideModel.findById(rideId)),
      user: publicUser(await userModel.findById(me.user_id)),
    });
  } catch (e) {
    throw mapDbError(e);
  }
}

/** POST /rides/:id/return  { station_id }  -> the finished ride */
async function returnVehicle(req, res) {
  const r = await ownRide(req);
  if (r.status === 'returned') throw conflict('This ride is already finished');

  const stationId = toInt(req.body?.station_id);
  const station = stationId === null ? null : await stationModel.findById(stationId);
  if (!station) throw notFound('Station not found');
  if (station.station_id !== r.start_station_id) throw conflict(`You can only return to ${r.from_station}`);
  if ((await stationModel.countDocked(station.station_id)) >= station.total_docks) throw conflict(`${station.name} is full`);

  const v = await vehicleModel.findById(r.vehicle_id);
  const batteryEnd = v ? battery.liveBattery(v) : r.battery_start;
  try {
    await rideModel.callReturn(r.ride_id, station.station_id, batteryEnd);
  } catch (e) {
    throw mapDbError(e);
  }
  res.json(ride(await rideModel.findById(r.ride_id)));
}

// HelpType (Dart enum) -> problem_reports.category
const HELP = {
  accident: { label: 'Accident', category: 'accident' },
  flattyre: { label: 'Flat tyre', category: 'brakes_wheels' },
  brakes: { label: 'Brakes not working', category: 'brakes_wheels' },
  damaged: { label: 'Vehicle broken', category: 'damaged_part' },
  battery: { label: 'Battery died', category: 'low_battery' },
  other: { label: 'Something else', category: 'other' },
};

/** POST /rides/:id/help  { type, location, details? } -> 201 the new report ("Need help?" button) */
async function requestHelp(req, res) {
  const r = await ownRide(req);
  if (r.status === 'returned') throw conflict('This ride is already finished');

  const key = String(req.body?.type ?? '').replace(/_/g, '').toLowerCase(); // flat_tyre / flatTyre both work
  const help = HELP[key];
  if (!help) throw badRequest('Unknown help type');
  const location = str(req.body?.location);
  if (!location) throw badRequest('Please tell staff where you are');
  const details = str(req.body?.details);

  // the app recognises an urgent request by the "[URGENT]" prefix, the DB also has is_urgent + location
  let note = `[URGENT] ${help.label} · at: ${location}`;
  if (details) note += ` · ${details}`;

  const id = await reportModel.create({
    user_id: req.user.user_id,
    vehicle_id: r.vehicle_id,
    ride_id: r.ride_id,
    category: help.category,
    is_urgent: true,
    location,
    details: note,
  });
  res.status(201).json(await reportModel.findById(id));
}

module.exports = { activeRide, myRides, myStats, borrow, returnVehicle, requestHelp, HELP };
