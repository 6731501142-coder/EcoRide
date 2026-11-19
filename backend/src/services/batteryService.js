// Battery simulation – a straight port of the battery section of AppStore (Dart).
// Riding: battery drops with the (estimated) distance, not with the time.
// Parked : every dock charges the vehicle, fast up to 80 % then slower up to 100 %.
// When the vehicles send their real battery level (IoT) this file can be replaced.
const config = require('../config');

const isBike = (codePrefix) => codePrefix === 'EB';

/** constants per vehicle type (EB = e-bike, ES = e-scooter) */
function specOf(codePrefix) {
  return isBike(codePrefix)
    ? { speedKmh: 12, pctPerKm: 1.5, fastPerHour: 80 / 3.5, slowPerHour: 20 / 1.5 }
    : { speedKmh: 15, pctPerKm: 3.0, fastPerHour: 80 / 2.5, slowPerHour: 20 / 1.5 };
}

/** estimated distance (km) after [usedSeconds] of borrowing */
function estimatedKm(codePrefix, usedSeconds, timeScale = config.timeScale) {
  const h = (Math.max(0, usedSeconds) / 3600) * timeScale;
  // first hour: moving 60 % of the time, after that only 10 %
  const movingHours = (h < 1 ? h : 1.0) * 0.6 + (h > 1 ? h - 1 : 0.0) * 0.1;
  return movingHours * specOf(codePrefix).speedKmh;
}

/** battery % after charging [seconds] starting from [from] % */
function charged(codePrefix, from, seconds, timeScale = config.timeScale) {
  const spec = specOf(codePrefix);
  let level = from;
  let h = (Math.max(0, seconds) / 3600) * timeScale;
  if (level < 80) {
    const need = (80 - level) / spec.fastPerHour;
    if (h <= need) return level + h * spec.fastPerHour;
    level = 80;
    h -= need;
  }
  const full = level + h * spec.slowPerHour;
  return full > 100 ? 100 : full;
}

const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

/**
 * Battery % right now. [v] is a row from vehicleModel (see its SELECT):
 *   status, current_station_id, battery_level, code_prefix,
 *   seconds_since_battery_update, ride_battery_start, ride_used_seconds
 */
function liveBattery(v, timeScale = config.timeScale) {
  if (v.status === 'in_use') {
    if (v.ride_battery_start == null) return v.battery_level; // no open ride found
    const used = estimatedKm(v.code_prefix, v.ride_used_seconds || 0, timeScale) * specOf(v.code_prefix).pctPerKm;
    return Math.floor(clamp(v.ride_battery_start - used, 0, 100));
  }
  if (v.status === 'maintenance') return v.battery_level; // being repaired: no charging
  if (v.current_station_id == null) return v.battery_level;
  return Math.floor(charged(v.code_prefix, v.battery_level, v.seconds_since_battery_update || 0, timeScale));
}

/** parked, available and not yet full */
const isCharging = (v, live) =>
  v.status === 'available' && v.current_station_id != null && live < 100;

/** minutes until the battery reaches the minimum (20 %) – null if already borrowable */
function minutesUntilReady(v, live, timeScale = config.timeScale, minBattery = config.minBattery) {
  if (live >= minBattery || !isCharging(v, live)) return null;
  const perHour = specOf(v.code_prefix).fastPerHour * timeScale;
  return Math.ceil(((minBattery - live) / perHour) * 60);
}

/** can a student borrow it right now? (AppStore.canBorrowVehicle) */
const canBorrow = (v, live, minBattery = config.minBattery) =>
  v.status === 'available' && v.current_station_id != null && live >= minBattery;

module.exports = { specOf, estimatedKm, charged, liveBattery, isCharging, minutesUntilReady, canBorrow, isBike };
