jest.mock('../src/models/feedbackModel');
const feedbackModel = require('../src/models/feedbackModel');
const c = require('../src/controllers/feedbackController');
const { run, fails, student } = require('./helpers');

const user = student();
beforeEach(() => {
  jest.resetAllMocks();
  feedbackModel.create.mockResolvedValue(5);
  feedbackModel.findById.mockResolvedValue({ feedback_id: 5 });
});

test('ok -> 201 and trimmed message', async () => {
  const { status, body } = await run(c.submit, { user, body: { topic: 'suggestion', message: '  Add more docks please ' } });
  expect(status).toBe(201);
  expect(body).toEqual({ feedback_id: 5 });
  expect(feedbackModel.create).toHaveBeenCalledWith({ user_id: 1, topic: 'suggestion', message: 'Add more docks please' });
});
test('Dart enum name appBug is accepted as app_bug', async () => {
  await run(c.submit, { user, body: { topic: 'appBug', message: 'The map is blank' } });
  expect(feedbackModel.create.mock.calls[0][0].topic).toBe('app_bug');
});
test.each(['app_bug', 'payment', 'account', 'suggestion', 'other'])('topic %s ok', async (topic) => {
  await run(c.submit, { user, body: { topic, message: 'hello there' } });
  expect(feedbackModel.create).toHaveBeenCalled();
});
test('bad topic / short / long message -> 400', async () => {
  expect(await fails(c.submit, { user, body: { topic: 'spam', message: 'hello there' } })).toMatchObject({ status: 400, message: 'Unknown topic' });
  expect(await fails(c.submit, { user, body: { message: 'hello there' } })).toMatchObject({ status: 400 });
  expect(await fails(c.submit, { user, body: { topic: 'other', message: ' hi ' } })).toMatchObject({ status: 400, message: 'Please tell us a bit more' });
  expect(await fails(c.submit, { user, body: { topic: 'other', message: 'x'.repeat(2001) } })).toMatchObject({ status: 400 });
  expect(feedbackModel.create).not.toHaveBeenCalled();
});
