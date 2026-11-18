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

test('only an active resident can create one review for a dorm', async (t) => {
  const originalGetConnection = db.getConnection;
  t.after(() => {
    db.getConnection = originalGetConnection;
  });
  let inserted;
  let committed = false;
  let rolledBack = false;
  db.getConnection = async () => ({
    async beginTransaction() {},
    async query(sql, params) {
      if (sql.includes('FROM booking_payments p')) {
        assert.match(sql, /p\.status = 'completed'/);
        assert.match(sql, /b\.status = 'confirmed'/);
        assert.match(sql, /r\.status = 'occupied'/);
        assert.match(sql, /b\.starts_at <= CURDATE\(\)/);
        assert.match(sql, /b\.ends_at >= CURDATE\(\)/);
        assert.deepEqual(params, [4, 12]);
        return [[{ id: 21 }]];
      }
      if (sql.includes('FROM dorm_reviews WHERE dorm_id')) {
        assert.match(sql, /reviewer_id/);
        return [[]];
      }
      if (sql.includes('INSERT INTO dorm_reviews')) {
        assert.match(sql, /reviewer_id/);
        inserted = params;
        return [{ insertId: 31 }];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async commit() {
      committed = true;
    },
    async rollback() {
      rolledBack = true;
    },
    release() {},
  });
  const res = makeResponse();

  await tenantController.createDormReview(
    {
      params: { dormId: '4' },
      user: { id: 12, role: 'tenant' },
      body: { rating: 5, comment: '  ห้องสะอาดและเดินทางสะดวก  ' },
    },
    res,
  );

  assert.equal(res.statusCode, 201);
  assert.deepEqual(inserted, [4, 12, 5, 'ห้องสะอาดและเดินทางสะดวก']);
  assert.equal(res.body.data.status, 'visible');
  assert.equal(committed, true);
  assert.equal(rolledBack, false);
});

test('a booking that is not an active stay cannot create a review', async (t) => {
  const originalGetConnection = db.getConnection;
  t.after(() => {
    db.getConnection = originalGetConnection;
  });
  let rolledBack = false;
  db.getConnection = async () => ({
    async beginTransaction() {},
    async query(sql) {
      assert.match(sql, /r\.status = 'occupied'/);
      return [[]];
    },
    async commit() {
      throw new Error('transaction must not commit');
    },
    async rollback() {
      rolledBack = true;
    },
    release() {},
  });
  const res = makeResponse();

  await tenantController.createDormReview(
    {
      params: { dormId: '4' },
      user: { id: 12, role: 'tenant' },
      body: { rating: 4, comment: 'ห้องพักดีและสะอาดมาก' },
    },
    res,
  );

  assert.equal(res.statusCode, 403);
  assert.equal(rolledBack, true);
});

test('non-tenants cannot create reviews and invalid ratings are rejected', async (t) => {
  const originalGetConnection = db.getConnection;
  t.after(() => {
    db.getConnection = originalGetConnection;
  });
  db.getConnection = async () => {
    throw new Error('database must not be queried');
  };
  const nonTenantResponse = makeResponse();
  const invalidRatingResponse = makeResponse();

  await tenantController.createDormReview(
    {
      params: { dormId: '4' },
      user: { id: 2, role: 'seller' },
      body: { rating: 5, comment: 'ห้องพักดีและสะอาดมาก' },
    },
    nonTenantResponse,
  );
  await tenantController.createDormReview(
    {
      params: { dormId: '4' },
      user: { id: 12, role: 'tenant' },
      body: { rating: 6, comment: 'ห้องพักดีและสะอาดมาก' },
    },
    invalidRatingResponse,
  );

  assert.equal(nonTenantResponse.statusCode, 403);
  assert.equal(invalidRatingResponse.statusCode, 400);
});

test('review list exposes only visible reviews and resident eligibility', async (t) => {
  const originalQuery = db.query;
  t.after(() => {
    db.query = originalQuery;
  });
  db.query = async (sql, params) => {
    if (sql.includes('SELECT id, name FROM dorms')) return [[{ id: 4, name: 'หอทดสอบ' }]];
    if (sql.includes('FROM dorm_reviews r')) {
      assert.match(sql, /r\.status = 'visible'/);
      assert.match(sql, /u\.id = r\.reviewer_id/);
      assert.deepEqual(params, [4]);
      return [[{
        id: 31,
        dormId: 4,
        author: 'ผู้เช่าทดสอบ',
        rating: 5,
        comment: 'ห้องพักสะอาดมาก',
        status: 'visible',
      }]];
    }
    if (sql.includes('FROM dorm_reviews WHERE')) return [[]];
    if (sql.includes('FROM booking_payments p')) return [[{ id: 21 }]];
    throw new Error(`Unexpected SQL: ${sql}`);
  };
  const res = makeResponse();

  await tenantController.getDormReviews(
    { params: { dormId: '4' }, user: { id: 12, role: 'tenant' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.data.canReview, true);
  assert.equal(res.body.data.hasReviewed, false);
  assert.equal(res.body.data.reviews[0].id, 31);
});
