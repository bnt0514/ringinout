/**
 * SQLite 데이터베이스 관리
 * 
 * 스키마:
 * - users: anon_user_id(PK), created_at, last_login_at
 * - subscriptions: anon_user_id(FK), store, plan, status, expires_at, last_verified_at
 */

const Database = require('better-sqlite3');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'ringinout.db');
const db = new Database(dbPath);

// DB 초기화 (테이블 생성)
function initialize() {
    console.log('🗄️  DB 초기화 중...');

    // users 테이블
    db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      anon_user_id TEXT PRIMARY KEY,
      created_at INTEGER NOT NULL,
      last_login_at INTEGER NOT NULL
    )
  `);

    // subscriptions 테이블
    db.exec(`
    CREATE TABLE IF NOT EXISTS subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      anon_user_id TEXT NOT NULL UNIQUE,
      store TEXT NOT NULL CHECK(store IN ('ios', 'android', 'manual')),
      plan TEXT NOT NULL CHECK(plan IN ('free', 'basic', 'premium', 'special')),
      status TEXT NOT NULL CHECK(status IN ('active', 'expired', 'canceled', 'grace')),
      expires_at INTEGER,
      last_verified_at INTEGER,
      FOREIGN KEY (anon_user_id) REFERENCES users(anon_user_id) ON DELETE CASCADE
    )
  `);

    // 인덱스 생성
    db.exec(`
    CREATE INDEX IF NOT EXISTS idx_subscriptions_anon_user_id 
    ON subscriptions(anon_user_id)
  `);

    console.log('✅ DB 초기화 완료');
}

// 유저 생성 또는 업데이트
function upsertUser(anonUserId) {
    const now = Date.now();
    const stmt = db.prepare(`
    INSERT INTO users (anon_user_id, created_at, last_login_at)
    VALUES (?, ?, ?)
    ON CONFLICT(anon_user_id) DO UPDATE SET last_login_at = ?
  `);
    stmt.run(anonUserId, now, now, now);
}

// 유저 조회
function getUser(anonUserId) {
    const stmt = db.prepare('SELECT * FROM users WHERE anon_user_id = ?');
    return stmt.get(anonUserId);
}

// 구독 생성 또는 업데이트
function upsertSubscription(anonUserId, data) {
    const { store, plan, status, expires_at, last_verified_at } = data;
    const stmt = db.prepare(`
    INSERT INTO subscriptions (anon_user_id, store, plan, status, expires_at, last_verified_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(anon_user_id) DO UPDATE SET
      store = ?,
      plan = ?,
      status = ?,
      expires_at = ?,
      last_verified_at = ?
  `);
    stmt.run(
        anonUserId, store, plan, status, expires_at, last_verified_at,
        store, plan, status, expires_at, last_verified_at
    );
}

// 구독 조회
function getSubscription(anonUserId) {
    const stmt = db.prepare('SELECT * FROM subscriptions WHERE anon_user_id = ?');
    return stmt.get(anonUserId);
}

module.exports = {
    initialize,
    upsertUser,
    getUser,
    upsertSubscription,
    getSubscription,
    db, // 직접 쿼리용
};
