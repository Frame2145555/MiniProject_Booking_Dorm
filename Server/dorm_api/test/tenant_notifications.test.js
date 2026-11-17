const test = require('node:test');
const assert = require('node:assert/strict');
const db = require('../config/db');
const tenantController = require('../controllers/tenantController');

const makeResponse = () => ({
  statusCode: 200,
  status(code) {
    this.statusCode = code;
    return this;
  },
  json(body) {
    this.body = body;
    return this;
  },
});

test('tenant notification list is scoped to the signed-in user', async (t) => {
  const originalQuery = db.query;
  t.after(() => {
    db.query = originalQuery;
  });
  let queryParams;
  db.query = async (_sql, params) => {
    queryParams = params;
    return [[{
      id: 21,
      type: 'dorm_report_resolved',
      title: 'รายงานของคุณได้รับการจัดการแล้ว',
      message: 'ตรวจสอบรายงานแล้ว',
      isRead: 0,
    }]];
  };
  const res = makeResponse();

  await tenantController.getNotifications({ user: { id: 12, role: 'tenant' } }, res);

  assert.deepEqual(queryParams, [12]);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.data[0].id, 21);
});

test('only tenants can read or update notifications', async (t) => {
  const originalQuery = db.query;
  t.after(() => {
    db.query = originalQuery;
  });
  db.query = async () => {
    throw new Error('query should not run for non-tenant');
  };
  const getResponse = makeResponse();
  const updateResponse = makeResponse();

  await tenantController.getNotifications({ user: { id: 99, role: 'admin' } }, getResponse);
  await tenantController.markNotificationsRead({ user: { id: 99, role: 'admin' } }, updateResponse);

  assert.equal(getResponse.statusCode, 403);
  assert.equal(updateResponse.statusCode, 403);
});

test('marking notifications read only updates the signed-in tenant records', async (t) => {
  const originalQuery = db.query;
  t.after(() => {
    db.query = originalQuery;
  });
  let queryParams;
  db.query = async (sql, params) => {
    assert.match(sql, /UPDATE user_notifications/);
    queryParams = params;
    return [{ affectedRows: 2 }];
  };
  const res = makeResponse();

  await tenantController.markNotificationsRead(
    { user: { id: 12, role: 'tenant' } },
    res,
  );

  assert.deepEqual(queryParams, [12]);
  assert.equal(res.body.markedRead, 2);
});
