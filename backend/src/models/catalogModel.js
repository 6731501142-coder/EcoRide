// small look-up tables: vehicle_types, rental_plans
const db = require('../db');

const listTypes = () => db.query('SELECT type_id, code_prefix, name FROM vehicle_types ORDER BY type_id');
const findType = async (id) =>
  (await db.query('SELECT type_id, code_prefix, name FROM vehicle_types WHERE type_id = ?', [id]))[0] || null;

const listPlans = () =>
  db.query('SELECT plan_id, name, duration_hours, price, is_active FROM rental_plans WHERE is_active = 1 ORDER BY plan_id');
const findPlan = async (id) =>
  (await db.query('SELECT plan_id, name, duration_hours, price, is_active FROM rental_plans WHERE plan_id = ? AND is_active = 1', [id]))[0] || null;

module.exports = { listTypes, findType, listPlans, findPlan };
