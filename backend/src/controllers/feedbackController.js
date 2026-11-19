// Profile > Report & feedback  (= submitFeedback in AppStore)
const feedbackModel = require('../models/feedbackModel');
const { badRequest } = require('../utils/errors');
const { str } = require('../utils/helpers');

const TOPICS = ['app_bug', 'payment', 'account', 'suggestion', 'other'];

/** POST /feedback  { topic, message } -> 201 */
async function submit(req, res) {
  const topic = String(req.body?.topic ?? '').replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase(); // appBug -> app_bug
  if (!TOPICS.includes(topic)) throw badRequest('Unknown topic');
  const message = str(req.body?.message);
  if (message.length < 5) throw badRequest('Please tell us a bit more');
  if (message.length > 2000) throw badRequest('Message is too long (max 2000 characters)');

  const id = await feedbackModel.create({ user_id: req.user.user_id, topic, message });
  res.status(201).json(await feedbackModel.findById(id));
}

module.exports = { submit, TOPICS };
