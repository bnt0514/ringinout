/**
 * RingInOut 구독 검증 서버
 * 
 * 목적: Google 로그인 인증 후 구독 플랜 검증만 수행
 * 원칙: 서버에는 사용자를 직접 식별할 수 없는 anon_user_id만 저장
 * 금지: 이메일/이름/프로필사진/Google sub/Firebase uid 원문 저장 금지
 */

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const admin = require('firebase-admin');

const authRoutes = require('./routes/auth');
const billingRoutes = require('./routes/billing');
const db = require('./db/database');

// Firebase Admin SDK 초기화
const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const app = express();
const PORT = process.env.PORT || 3000;

// 미들웨어
app.use(helmet()); // 보안 헤더
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
}));
app.use(express.json());

// 요청 로깅 (민감정보 제외)
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    // ⚠️ req.body에 토큰/이메일 등이 있어도 로그에 찍지 않음
    next();
});

// 라우트
app.use('/auth', authRoutes);
app.use('/billing', billingRoutes);

// 헬스체크
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404 핸들러
app.use((req, res) => {
    res.status(404).json({ error: 'Not Found' });
});

// 에러 핸들러
app.use((err, req, res, next) => {
    console.error('❌ Error:', err.message);
    // ⚠️ 스택 트레이스에 민감정보가 있을 수 있으므로 클라이언트에 전송하지 않음
    res.status(err.status || 500).json({
        error: err.message || 'Internal Server Error',
    });
});

// DB 초기화 후 서버 시작
db.initialize();

app.listen(PORT, () => {
    console.log(`✅ RingInOut 서버 시작: http://localhost:${PORT}`);
    console.log(`📌 구독 검증 목적 외 사용 금지`);
    console.log(`📌 민감정보(이메일/이름/사진/uid) 저장 금지`);
});

module.exports = { app, admin };
