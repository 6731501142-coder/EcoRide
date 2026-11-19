// Adds the "live" fields the app needs to a vehicle row, and builds station availability
// (= AppStore.liveBattery / canBorrowVehicle / isCharging / availability).
const battery = require('./batteryService');
const config = require('../config');

/** Row from vehicleModel -> JSON for the app (DB column names + live fields). */
function decorate(v, opts = {}) {
  const timeScale = opts.timeScale ?? config.timeScale;
  const live = battery.liveBattery(v, timeScale);
  return {
    vehicle_id: v.vehicle_id,
    vehicle_code: v.vehicle_code,
    type_id: v.type_id,
    code_prefix: v.code_prefix,
    type_name: v.type_name,
    current_station_id: v.current_station_id,
    station_name: v.station_name ?? null,
    battery_level: v.battery_level, // value stored in the DB
    status: v.status,
    live_battery: live, // what the app should show
    can_borrow: battery.canBorrow(v, live),
    is_charging: battery.isCharging(v, live),
    minutes_until_ready: battery.minutesUntilReady(v, live, timeScale),
  };
}

/** parked vehicles: borrowable first, then the fullest battery first (AppStore.vehiclesAt) */
function sortForStation(list) {
  return [...list].sort((a, b) => {
    const ra = a.can_borrow ? 0 : 1;
    const rb = b.can_borrow ? 0 : 1;
    if (ra !== rb) return ra - rb;
    return b.live_battery - a.live_battery;
  });
}

/**
 * Availability of one station. [docked] = decorated vehicles whose current_station_id is this station.
 * Field names follow VIEW v_station_availability, plus ready_bikes / ready_scooters for the app.
 */
function availability(station, docked) {
  const ready = docked.filter((v) => v.can_borrow);
  const bikesReady = ready.filter((v) => battery.isBike(v.code_prefix)).length;
  const scootersReady = ready.length - bikesReady;
  const free = station.total_docks - docked.length;
  return {
    vehicles_docked: docked.length,
    free_docks: free,
    bikes: docked.filter((v) => battery.isBike(v.code_prefix)).length,
    scooters: docked.filter((v) => !battery.isBike(v.code_prefix)).length,
    ready_bikes: bikesReady,
    ready_scooters: scootersReady,
    ready_to_ride: ready.length,
    is_full: free <= 0,
  };
}

/** station row + availability, given every parked decorated vehicle */
function withAvailability(station, allDockedDecorated) {
  const docked = allDockedDecorated.filter((v) => v.current_station_id === station.station_id);
  return {
    station_id: station.station_id,
    name: station.name,
    total_docks: station.total_docks,
    icon_key: station.icon_key,
    photo_url: station.photo_url ?? null,
    latitude: station.latitude ?? null,
    longitude: station.longitude ?? null,
    is_active: !!station.is_active,
    ...availability(station, docked),
  };
}

module.exports = { decorate, sortForStation, availability, withAvailability };
