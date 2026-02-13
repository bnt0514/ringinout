/**
 * Auth 라우트
 * 
 * POST /auth/session - Firebase ID Token 검증 후 세션 생성
 */

const express = require('express');
const { generateAnonUserId } = require('../utils/crypto');
const { upsertUser, upsertSubscription } = require('../db/database');
const { admin } = require('../index');

const router = express.Router();

/**
 * POST /auth/session
 * 
 * Body: { idToken: string }
 * Response: { success: true, message: 'Session created' }
 */
router.post('/session', async (req, res, next) => {
    const { idToken } = req.body;

    if (!idToken) {
        return res.status(400).json({ error: 'idToken is required' });
    }

    try {
        // Firebase ID Token 검증
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;

        // ⚠️ 이메일/이름 등은 절대 저장하지 않음
        // const email = decodedToken.email; // 읽기만 하고 저장 안함
        // const name = decodedToken.name;   // 읽기만 하고 저장 안함

        // HMAC 기반 익명 ID 생성
        const anonUserId = generateAnonUserId(firebaseUid);

        // DB에 유저 생성/업데이트 (anon_user_id만 저장)
        upsertUser(anonUserId);

        // 기본 구독 생성 (없으면 free 플랜)
        const existingSub = require('../db/database').getSubscription(anonUserId);
        if (!existingSub) {
            upsertSubscription(anonUserId, {
                store: 'manual',
                plan: 'free',
                status: 'active',
                expires_at: null,
                last_verified_at: Date.now(),
            });
        }

        console.log('✅ Session created for anon user');

        res.json({
            success: true,
            message: 'Session created',
        });
    } catch (error) {
        console.error('❌ Session creation failed:', error.message);
        next(error);
    }
});

module.exports = router;
