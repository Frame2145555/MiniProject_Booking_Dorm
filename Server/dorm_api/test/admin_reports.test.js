const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const http = require('http');
const adminRoutes = require('../routes/adminRoutes');

const makeDb = () => {
  const report = {
    id: 8,
    dormId: 3,
    dormName: 'หอทดสอบ',
    ownerName: 'เจ้าของหอ',
    reporterId: 12,
    reporterName: 'ผู้เช่าทดสอบ',
    reporterEmail: 'tenant@test.com',
    category: 'pricing',
    description: 'ราคาในประกาศไม่ตรงกับที่แจ้ง',
    status: 'pending',
    adminNote: null,
  };
  return {
    report,
    async query(sql, params = []) {
      if (sql.includes('FROM user_dorm_reports r')) {
        return [[{ ...report }]];
      }
      if (sql.includes('UPDATE user_dorm_reports')) {
        if (report.status !== 'pending') return [{ affectedRows: 0 }];
        [report.status, , report.adminNote] = params;
        return [{ affectedRows: 1 }];
      }
      if (sql.includes("status = 'pending'")) {
        return report.status === 'pending' ? [[{ dormId: report.dormId }]] : [[]];
      }
      if (sql.includes('INSERT INTO admin_audit_logs')) {
        return [{ affectedRows: 1 }];
      }
      if (sql.includes('FROM user_dorm_reports WHERE id')) {
        return [[{
          id: report.id,
          dormId: report.dormId,
          status: report.status,
          adminNote: report.adminNote,
          reviewedAt: '2026-11-17 10:00:00',
        }]];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
};

const startApp = async (db) => {
  const app = express();
  app.use(express.json());
  app.use('/api/admin', adminRoutes(db, {
    requireRole: (role) => (req, _res, next) => {
      req.user = { id: 99, role };
      next();
    },
  }));
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return {
    server,
    baseUrl: `http://127.0.0.1:${server.address().port}/api/admin/reports`,
  };
};

test('admin can list reports and filter by status', async (t) => {
  const db = makeDb();
  const { server, baseUrl } = await startApp(db);
  t.after(() => server.close());

  const response = await fetch(`${baseUrl}?status=pending`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.count, 1);
  assert.equal(body.data[0].dormName, 'หอทดสอบ');
});

test('admin must provide a valid status and review note', async (t) => {
  const { server, baseUrl } = await startApp(makeDb());
  t.after(() => server.close());

  const invalidStatus = await fetch(`${baseUrl}/8`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'pending', note: 'ตรวจแล้ว' }),
  });
  assert.equal(invalidStatus.status, 400);

  const missingNote = await fetch(`${baseUrl}/8`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'resolved', note: ' ' }),
  });
  assert.equal(missingNote.status, 400);
});

test('admin can resolve a pending report only once', async (t) => {
  const db = makeDb();
  const { server, baseUrl } = await startApp(db);
  t.after(() => server.close());
  const request = () => fetch(`${baseUrl}/8`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'resolved', note: 'ตรวจสอบและแก้ไขแล้ว' }),
  });

  const first = await request();
  const firstBody = await first.json();
  const second = await request();

  assert.equal(first.status, 200);
  assert.equal(firstBody.data.status, 'resolved');
  assert.equal(second.status, 409);
});
