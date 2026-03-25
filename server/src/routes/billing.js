/**
 * Billing 라우트
 * 
 * GET /billing/status - 현재 구독 플랜 상태 조회
 * POST /billing/verify - 스토어 영수증 검증 후 구독 업데이트
 */

const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const { getSubscription, upsertSubscription } = require('../db/database');

const router = express.Router();

/**
 * GET /billing/status
 * 
 * Headers: Authorization: Bearer <idToken>
 * Response: { plan, status, expires_at, last_verified_at }
 */
router.get('/status', authenticateToken, (req, res, next) => {
    try {
        const anonUserId = req.anonUserId;

        const subscription = getSubscription(anonUserId);

        if (!subscription) {
            // 구독 정보 없으면 free 플랜 생성
            upsertSubscription(anonUserId, {
                store: 'manual',
                plan: 'free',
                status: 'active',
                expires_at: null,
                last_verified_at: Date.now(),
            });

            return res.json({
                plan: 'free',
                status: 'active',
                expires_at: null,
                last_verified_at: Date.now(),
            });
        }

        res.json({
            plan: subscription.plan,
            status: subscription.status,
            expires_at: subscription.expires_at,
            last_verified_at: subscription.last_verified_at,
        });
    } catch (error) {
        console.error('❌ Billing status failed:', error.message);
        next(error);
    }
});

/**
 * POST /billing/verify
 * 
 * Headers: Authorization: Bearer <idToken>
 * Body: { store: 'ios' | 'android', receipt: string, purchaseToken?: string }
 * Response: { success: true, plan, status, expires_at }
 * 
 * TODO: 실제 App Store / Play Store 영수증 검증 구현
 */
router.post('/verify', authenticateToken, async (req, res, next) => {
    try {
        const anonUserId = req.anonUserId;
        const { store, receipt, purchaseToken } = req.body;

        if (!store || !receipt) {
            return res.status(400).json({ error: 'store and receipt are required' });
        }

        // TODO: 실제 스토어 검증 로직 구현
        // iOS: App Store Server API
        // Android: Google Play Developer API

        // 임시: 검증 성공으로 가정하고 premium 플랜 부여
        const now = Date.now();
        const expiresAt = now + (30 * 24 * 60 * 60 * 1000); // 30일 후

        upsertSubscription(anonUserId, {
            store,
            plan: 'premium',
            status: 'active',
            expires_at: expiresAt,
            last_verified_at: now,
        });

        console.log('✅ Subscription verified (임시)');

        res.json({
            success: true,
            plan: 'premium',
            status: 'active',
            expires_at: expiresAt,
        });
    } catch (error) {
        console.error('❌ Billing verify failed:', error.message);
        next(error);
    }
});

module.exports = router;
