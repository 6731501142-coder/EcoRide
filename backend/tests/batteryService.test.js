const b = require('../src/services/batteryService');
const { vehicleRow, scooterRow } = require('./helpers');

describe('specOf', () => {
  test('e-bike (EB) and e-scooter (ES) constants', () => {
    expect(b.specOf('EB')).toEqual({ speedKmh: 12, pctPerKm: 1.5, fastPerHour: 80 / 3.5, slowPerHour: 20 / 1.5 });
    expect(b.specOf('ES')).toEqual({ speedKmh: 15, pctPerKm: 3.0, fastPerHour: 80 / 2.5, slowPerHour: 20 / 1.5 });
  });
});

describe('estimatedKm (distance while riding)', () => {
  test('first hour counts 60% moving, later hours only 10%', () => {
    expect(b.estimatedKm('EB', 3600, 1)).toBeCloseTo(0.6 * 12);
    expect(b.estimatedKm('EB', 2 * 3600, 1)).toBeCloseTo((0.6 + 0.1) * 12);
    expect(b.estimatedKm('ES', 1800, 1)).toBeCloseTo(0.5 * 0.6 * 15);
  });
  test('time scale speeds the simulation up', () => {
    expect(b.estimatedKm('EB', 120, 30)).toBeCloseTo(b.estimatedKm('EB', 3600, 1));
  });
  test('0 or negative time = 0 km', () => {
    expect(b.estimatedKm('EB', 0, 1)).toBe(0);
    expect(b.estimatedKm('EB', -50, 1)).toBe(0);
  });
});

describe('charged (while parked)', () => {
  test('fast charge up to 80%: e-bike 0 -> 80 takes 3.5 h', () => {
    expect(b.charged('EB', 0, 3.5 * 3600, 1)).toBeCloseTo(80);
    expect(b.charged('EB', 0, 1.75 * 3600, 1)).toBeCloseTo(40);
  });
  test('slower 80 -> 100 afterwards (1.5 h) and never above 100', () => {
    expect(b.charged('EB', 0, 5 * 3600, 1)).toBeCloseTo(100);
    expect(b.charged('EB', 0, 50 * 3600, 1)).toBe(100);
    expect(b.charged('EB', 80, 0.75 * 3600, 1)).toBeCloseTo(90);
  });
  test('e-scooter charges faster: 0 -> 80 in 2.5 h', () => {
    expect(b.charged('ES', 0, 2.5 * 3600, 1)).toBeCloseTo(80);
  });
  test('a vehicle that came back at 0% is borrowable (20%) in under an hour', () => {
    expect(b.charged('ES', 0, 0.625 * 3600, 1)).toBeCloseTo(20);
    expect(b.charged('EB', 0, 0.875 * 3600, 1)).toBeCloseTo(20);
  });
  test('time scale', () => {
    expect(b.charged('ES', 0, 300, 30)).toBeCloseTo(80); // 5 real minutes x30 = 2.5 h
  });
});

describe('liveBattery', () => {
  test('riding: e-bike 1 h from 90% -> 79%', () => {
    const v = vehicleRow({ status: 'in_use', current_station_id: null, ride_battery_start: 90, ride_used_seconds: 3600 });
    expect(b.liveBattery(v, 1)).toBe(79);
  });
  test('riding: e-scooter 70% after 1 h -> 43%', () => {
    const v = scooterRow({ status: 'in_use', current_station_id: null, ride_battery_start: 70, ride_used_seconds: 3600 });
    expect(b.liveBattery(v, 1)).toBe(43);
  });
  test('riding: never below 0', () => {
    const v = scooterRow({ status: 'in_use', current_station_id: null, ride_battery_start: 10, ride_used_seconds: 100 * 3600 });
    expect(b.liveBattery(v, 1)).toBe(0);
  });
  test('riding but no open ride found -> the stored battery', () => {
    expect(b.liveBattery(vehicleRow({ status: 'in_use', current_station_id: null, battery_level: 55 }), 1)).toBe(55);
  });
  test('parked: charges (scooter 12% + 1 h = 44%)', () => {
    expect(b.liveBattery(scooterRow({ battery_level: 12, seconds_since_battery_update: 3600 }), 1)).toBe(44);
  });
  test('parked just now: same as stored', () => {
    expect(b.liveBattery(vehicleRow({ battery_level: 79 }), 1)).toBe(79);
  });
  test('maintenance does not charge', () => {
    expect(b.liveBattery(vehicleRow({ status: 'maintenance', battery_level: 30, seconds_since_battery_update: 99999 }), 1)).toBe(30);
  });
  test('not docked anywhere -> stored value', () => {
    expect(b.liveBattery(vehicleRow({ current_station_id: null, battery_level: 40, seconds_since_battery_update: 99999 }), 1)).toBe(40);
  });
});

describe('isCharging / minutesUntilReady / canBorrow', () => {
  test('charging = parked + available + below 100', () => {
    expect(b.isCharging(vehicleRow(), 79)).toBe(true);
    expect(b.isCharging(vehicleRow(), 100)).toBe(false);
    expect(b.isCharging(vehicleRow({ status: 'maintenance' }), 50)).toBe(false);
    expect(b.isCharging(vehicleRow({ status: 'in_use', current_station_id: null }), 50)).toBe(false);
  });
  test('minutes until 20%', () => {
    expect(b.minutesUntilReady(scooterRow({ battery_level: 12 }), 12, 1)).toBe(15);
    expect(b.minutesUntilReady(vehicleRow({ battery_level: 10 }), 10, 1)).toBe(27);
  });
  test('null when already borrowable or not charging', () => {
    expect(b.minutesUntilReady(vehicleRow(), 79, 1)).toBeNull();
    expect(b.minutesUntilReady(vehicleRow({ status: 'maintenance' }), 5, 1)).toBeNull();
  });
  test('borrow needs available + docked + battery >= 20', () => {
    expect(b.canBorrow(vehicleRow(), 20)).toBe(true);
    expect(b.canBorrow(vehicleRow(), 19)).toBe(false);
    expect(b.canBorrow(vehicleRow({ status: 'in_use' }), 90)).toBe(false);
    expect(b.canBorrow(vehicleRow({ status: 'maintenance' }), 90)).toBe(false);
    expect(b.canBorrow(vehicleRow({ current_station_id: null }), 90)).toBe(false);
  });
});
